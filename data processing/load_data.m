function [F_raw, F, F_deconv, ops, stat, ...
          iscell_cells, iscell_cells_idx, ...
          stat_false, iscell_false] = load_data(suite2p_path)

    % ---- Sorties par défaut ----
    F_raw           = [];
    F               = [];
    F_deconv        = [];
    ops             = [];
    stat            = [];
    iscell_raw      = [];
    iscell_cells    = [];
    iscell_cells_idx = [];
    stat_false      = [];
    iscell_false    = [];
    F_deconv_raw    = [];

    [~, ~, ext] = fileparts(suite2p_path);

    % =========================================================
    % CAS 1 : dossier Suite2p contenant des .npy
    % =========================================================
    if isfolder(suite2p_path)

        FPath      = fullfile(suite2p_path, 'F.npy');
        SpksPath   = fullfile(suite2p_path, 'spks.npy');
        StatPath   = fullfile(suite2p_path, 'stat.npy');
        IscellPath = fullfile(suite2p_path, 'iscell.npy');
        OpsPath    = fullfile(suite2p_path, 'ops.npy');

        if isfile(FPath)
            F_raw = readNPY(FPath);
        end

        if isfile(SpksPath)
            F_deconv_raw = readNPY(SpksPath);
        end

        if isfile(IscellPath)
            iscell_raw = readNPY(IscellPath);
        end

        if isfile(StatPath) || isfile(OpsPath)
            try
                mod = py.importlib.import_module('python_function');

                if isfile(StatPath)
                    stat = mod.read_npy_file(StatPath);
                end

                if isfile(OpsPath)
                    ops = mod.read_npy_file(OpsPath);
                end

            catch ME
                warning('Chargement Python impossible: %s', ME.message);
                stat = [];
                ops = [];
            end
        end

    % =========================================================
    % CAS 2 : fichier .mat
    % =========================================================
    elseif strcmpi(ext, '.mat') && isfile(suite2p_path)

        data = load(suite2p_path);

        if isfield(data, 'F')
            F_raw = data.F;
        end

        if isfield(data, 'spks')
            F_deconv_raw = data.spks;
        end

        if isfield(data, 'iscell')
            iscell_raw = data.iscell;
        end

        if isfield(data, 'ops')
            ops = data.ops;
        end

        if isfield(data, 'stat')
            stat = data.stat;
        end

    else
        warning('Chemin non reconnu ou absent : %s', suite2p_path);
        return;
    end

    % =========================================================
    % HARMONISATION DES TAILLES F / iscell / spks
    % =========================================================
    if ~isempty(F_raw)

        nF = size(F_raw, 1);

        if ~isempty(iscell_raw)
            nI = size(iscell_raw, 1);
        else
            nI = nF;
            iscell_raw = [ones(nF,1), zeros(nF,1)];
        end

        nMin = min(nF, nI);

        if nF ~= nI
            warning('F et iscell ont des tailles différentes (%d vs %d). Troncature à %d.', ...
                nF, nI, nMin);
        end

        F_raw = F_raw(1:nMin, :);
        iscell_raw = iscell_raw(1:nMin, :);

        if ~isempty(F_deconv_raw)
            nS = size(F_deconv_raw, 1);
            nMin2 = min(nMin, nS);

            if nS ~= nMin
                warning('F et spks ont des tailles différentes (%d vs %d). Troncature à %d.', ...
                    nMin, nS, nMin2);
            end

            F_raw = F_raw(1:nMin2, :);
            iscell_raw = iscell_raw(1:nMin2, :);
            F_deconv_raw = F_deconv_raw(1:nMin2, :);
            nMin = nMin2;
        end

        % =====================================================
        % FILTRAGE CELLULES / NON-CELLULES
        % =====================================================
        keepMask  = logical(iscell_raw(:,1));
        falseMask = ~keepMask;

        iscell_cells_idx = find(keepMask);

        F = double(F_raw(keepMask, :));
        iscell_cells = iscell_raw(keepMask, :);
        iscell_false = iscell_raw(falseMask, :);

        if ~isempty(F_deconv_raw)
            F_deconv = double(F_deconv_raw(keepMask, :));
        end

        % =====================================================
        % FILTRAGE STAT
        % =====================================================
        if ~isempty(stat)

            if isa(stat, 'py.list')
                idx_true  = find(keepMask);
                idx_false = find(falseMask);

                stat_false = subset_pylist(stat, idx_false);
                stat       = subset_pylist(stat, idx_true);

            else
                try
                    stat_false = stat(falseMask);
                    stat       = stat(keepMask);
                catch
                    warning('Impossible de filtrer stat avec keepMask.');
                end
            end
        end

    else
        warning('F absent dans : %s', suite2p_path);
    end

    % =========================================================
    % SUPPRESSION DES CELLULES AVEC F == 0
    % =========================================================
    if ~isempty(F)

        rowsWithZero = all(F == 0, 2);

        if any(rowsWithZero)

            F(rowsWithZero, :) = [];

            if ~isempty(F_deconv) && size(F_deconv,1) == numel(rowsWithZero)
                F_deconv(rowsWithZero, :) = [];
            end

            if ~isempty(iscell_cells) && size(iscell_cells,1) == numel(rowsWithZero)
                iscell_cells(rowsWithZero, :) = [];
            end

            if ~isempty(iscell_cells_idx) && numel(iscell_cells_idx) == numel(rowsWithZero)
                iscell_cells_idx(rowsWithZero) = [];
            end

            if ~isempty(stat)
                if isa(stat, 'py.list')
                    stat = subset_pylist(stat, find(~rowsWithZero));
                else
                    try
                        stat(rowsWithZero) = [];
                    catch
                        warning('Impossible de supprimer rowsWithZero dans stat.');
                    end
                end
            end
        end

        fprintf('Suppression de %d cellules à cause de F==0.\n', sum(rowsWithZero));
    end

    % =========================================================
    % CONVERSION FINALE EN TYPES MATLAB
    % =========================================================
    ops  = make_matlab_saveable_recursive(ops);
    stat = make_matlab_saveable_recursive(stat);

end


function out = subset_pylist(pylist, idx)

    out = cell(1, numel(idx));
    np = py.importlib.import_module('numpy');

    for k = 1:numel(idx)

        py_idx = py.int(idx(k)-1);
        dict = pylist{py_idx};

        keys = cellfun(@char, cell(py.list(dict.keys())), ...
            'UniformOutput', false);

        s = struct();

        for kk = 1:numel(keys)
            key = keys{kk};
            value = dict{key};
            s.(key) = py_to_mat(value, np);
        end

        out{k} = s;
    end
end


function val = py_to_mat(value, np)

    try
        if isa(value, 'py.numpy.ndarray')
            val = double(np.array(value).flatten().tolist());
            return;
        end
    catch
    end

    if isa(value,'py.list') || isa(value,'py.tuple')
        try
            val = double(py.array.array('d', np.array(value)));
        catch
            val = cellfun(@double, cell(value));
        end
        return;
    end

    try
        val = double(value);
        return;
    catch
    end

    try
        val = char(value);
    catch
        val = value;
    end
end


function out = make_matlab_saveable_recursive(x)

    if isempty(x)
        out = [];
        return;
    end

    cls = class(x);

    if isnumeric(x) || islogical(x) || ischar(x) || isstring(x)
        out = x;
        return;
    end

    if iscell(x)
        out = cell(size(x));
        for i = 1:numel(x)
            out{i} = make_matlab_saveable_recursive(x{i});
        end
        return;
    end

    if isstruct(x)
        out = x;
        for j = 1:numel(x)
            fns = fieldnames(x(j));
            for k = 1:numel(fns)
                fn = fns{k};
                out(j).(fn) = make_matlab_saveable_recursive(x(j).(fn));
            end
        end
        return;
    end

    if startsWith(cls, 'py.')
        out = pyobj_to_matlab(x);
        return;
    end

    try
        out = double(x);
    catch
        out = [];
    end
end


function out = pyobj_to_matlab(x)

    cls = class(x);

    if strcmp(cls, 'py.numpy.ndarray')
        try
            out = double(x);
            return;
        catch
        end

        try
            out = cell(x.tolist());
            out = make_matlab_saveable_recursive(out);
            return;
        catch
        end
    end

    if strcmp(cls, 'py.dict')
        out = struct();
        keys = cell(py.list(x.keys()));

        for i = 1:numel(keys)
            key_char = char(keys{i});
            safe_key = matlab.lang.makeValidName(key_char);
            out.(safe_key) = make_matlab_saveable_recursive(x{keys{i}});
        end

        return;
    end

    if strcmp(cls, 'py.list') || strcmp(cls, 'py.tuple')
        c = cell(x);
        out = cell(size(c));

        for i = 1:numel(c)
            out{i} = make_matlab_saveable_recursive(c{i});
        end

        return;
    end

    try
        out = double(x);
        return;
    catch
    end

    try
        out = logical(x);
        return;
    catch
    end

    try
        out = char(x);
        return;
    catch
    end

    out = [];
end