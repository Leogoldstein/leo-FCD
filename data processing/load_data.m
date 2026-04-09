function [F_unsorted, F, F_deconv, ops, stat, iscell, stat_false, iscell_false] = load_data(suite2p_path)

    % ---- Sorties par défaut : tout optionnel ----
    F_unsorted   = [];
    F            = [];
    F_deconv     = [];
    ops          = [];
    stat         = [];
    iscell       = [];
    stat_false   = [];
    iscell_false = [];

    F_deconv_unsorted = [];
    iscell_raw = [];
    keepMask = [];
    falseMask = [];

    [~, ~, ext] = fileparts(suite2p_path);

    % =========================================================
    % CAS 1 : dossier contenant des .npy
    % =========================================================
    if isfolder(suite2p_path)

        newFPath      = fullfile(suite2p_path, 'F.npy');
        newSpksPath   = fullfile(suite2p_path, 'spks.npy');
        newStatPath   = fullfile(suite2p_path, 'stat.npy');
        newIscellPath = fullfile(suite2p_path, 'iscell.npy');
        newOpsPath    = fullfile(suite2p_path, 'ops.npy');

        % ---- Chargement indépendant de chaque fichier ----
        if isfile(newFPath)
            F_unsorted = readNPY(newFPath);
        end

        if isfile(newSpksPath)
            F_deconv_unsorted = readNPY(newSpksPath);
        end

        if isfile(newIscellPath)
            iscell_raw = readNPY(newIscellPath);
        end

        % ---- Chargement Python optionnel ----
        if isfile(newStatPath) || isfile(newOpsPath)
            try
                mod = py.importlib.import_module('python_function');

                if isfile(newStatPath)
                    stat = mod.read_npy_file(newStatPath);
                end

                if isfile(newOpsPath)
                    ops = mod.read_npy_file(newOpsPath);
                end

            catch ME
                warning('Chargement Python impossible: %s', ME.message);
                stat = [];
                ops = [];
            end
        end

        % ---- Séparation cellules / non-cellules si possible ----
        if ~isempty(F_unsorted) && ~isempty(iscell_raw)

            nF = size(F_unsorted, 1);
            nI = size(iscell_raw, 1);
            nMin = min(nF, nI);

            if nF ~= nI
                warning('F et iscell ont des tailles différentes (%d vs %d). Troncature à %d.', ...
                    nF, nI, nMin);
            end

            F_unsorted = F_unsorted(1:nMin, :);
            iscell_raw = iscell_raw(1:nMin, :);

            if ~isempty(F_deconv_unsorted)
                F_deconv_unsorted = F_deconv_unsorted(1:min(size(F_deconv_unsorted,1), nMin), :);
                if size(F_deconv_unsorted,1) ~= nMin
                    nMin2 = min(size(F_deconv_unsorted,1), nMin);
                    F_unsorted = F_unsorted(1:nMin2, :);
                    iscell_raw = iscell_raw(1:nMin2, :);
                    nMin = nMin2;
                end
            end

            keepMask  = logical(iscell_raw(:,1));
            falseMask = ~keepMask;

            F = double(F_unsorted(keepMask, :));
            iscell = iscell_raw(keepMask, :);
            iscell_false = iscell_raw(falseMask, :);

            if ~isempty(F_deconv_unsorted)
                F_deconv = double(F_deconv_unsorted(keepMask, :));
            end

            if ~isempty(stat)
                if isa(stat, 'py.list')
                    idx_true  = find(keepMask);
                    idx_false = find(falseMask);

                    stat_false = subset_pylist(stat, idx_false);
                    stat       = subset_pylist(stat, idx_true);
                else
                    try
                        stat_false = stat(falseMask);
                        stat = stat(keepMask);
                    catch
                        warning('Impossible de filtrer stat avec keepMask.');
                    end
                end
            end

        else
            % Pas de séparation possible
            if ~isempty(F_unsorted)
                F = double(F_unsorted);
            end

            if ~isempty(F_deconv_unsorted)
                F_deconv = double(F_deconv_unsorted);
            end

            if ~isempty(iscell_raw)
                iscell = iscell_raw;
            end
        end

    % =========================================================
    % CAS 2 : fichier .mat
    % =========================================================
    elseif strcmpi(ext, '.mat') && isfile(suite2p_path)

        data = load(suite2p_path);

        if isfield(data, 'F')
            F_unsorted = data.F;
        end

        if isfield(data, 'spks')
            F_deconv_unsorted = data.spks;
        end

        if isfield(data, 'iscell')
            iscell_raw = data.iscell;
        end

        if isfield(data, 'ops')
            ops = make_matlab_saveable_recursive(data.ops);
        end

        if isfield(data, 'stat')
            stat = data.stat;
        end

        if ~isempty(F_unsorted) && ~isempty(iscell_raw)

            nF = size(F_unsorted, 1);
            nI = size(iscell_raw, 1);
            nMin = min(nF, nI);

            if nF ~= nI
                warning('F et iscell ont des tailles différentes (%d vs %d). Troncature à %d.', ...
                    nF, nI, nMin);
            end

            F_unsorted = F_unsorted(1:nMin, :);
            iscell_raw = iscell_raw(1:nMin, :);

            if ~isempty(F_deconv_unsorted)
                F_deconv_unsorted = F_deconv_unsorted(1:min(size(F_deconv_unsorted,1), nMin), :);
                if size(F_deconv_unsorted,1) ~= nMin
                    nMin2 = min(size(F_deconv_unsorted,1), nMin);
                    F_unsorted = F_unsorted(1:nMin2, :);
                    iscell_raw = iscell_raw(1:nMin2, :);
                    nMin = nMin2;
                end
            end

            keepMask  = iscell_raw(:,1) > 0;
            falseMask = ~keepMask;

            F = double(F_unsorted(keepMask, :));
            iscell = iscell_raw(keepMask, :);
            iscell_false = iscell_raw(falseMask, :);

            if ~isempty(F_deconv_unsorted)
                F_deconv = double(F_deconv_unsorted(keepMask, :));
            end

            if ~isempty(stat)
                try
                    stat_false = stat(falseMask);
                    stat = stat(keepMask);
                catch
                    warning('Impossible de filtrer stat avec keepMask.');
                end
            end

        else
            if ~isempty(F_unsorted)
                F = double(F_unsorted);
            end

            if ~isempty(F_deconv_unsorted)
                F_deconv = double(F_deconv_unsorted);
            end

            if ~isempty(iscell_raw)
                iscell = iscell_raw;
            end
        end

    else
        warning('Chemin non reconnu ou absent : %s', suite2p_path);
        return;
    end

    % =========================================================
    % SUPPRESSION DES CELLULES AVEC F == 0
    % seulement si F existe
    % =========================================================
    if ~isempty(F)
        rowsWithZero = all(F == 0, 2);

        if any(rowsWithZero)
            F(rowsWithZero, :) = [];

            if ~isempty(F_deconv) && size(F_deconv,1) == numel(rowsWithZero)
                F_deconv(rowsWithZero, :) = [];
            end

            if ~isempty(iscell) && size(iscell,1) == numel(rowsWithZero)
                iscell(rowsWithZero, :) = [];
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
    ops          = make_matlab_saveable_recursive(ops);
end


function out = subset_pylist(pylist, idx)
    out = cell(1, numel(idx));
    np = py.importlib.import_module('numpy');

    for k = 1:numel(idx)
        py_idx = py.int(idx(k)-1);
        dict = pylist{py_idx};

        keys = cellfun(@char, cell(py.list(dict.keys())), 'UniformOutput', false);

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

    % Déjà MATLAB-safe
    if isnumeric(x) || islogical(x) || ischar(x) || isstring(x)
        out = x;
        return;
    end

    % Cell array
    if iscell(x)
        out = cell(size(x));
        for i = 1:numel(x)
            out{i} = make_matlab_saveable_recursive(x{i});
        end
        return;
    end

    % Struct / struct array
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

    % Objets Python
    if startsWith(cls, 'py.')
        out = pyobj_to_matlab(x);
        return;
    end

    % Fallback
    try
        out = double(x);
    catch
        out = [];
    end
end


function out = pyobj_to_matlab(x)

    cls = class(x);

    % numpy array
    if strcmp(cls, 'py.numpy.ndarray')
        try
            out = double(x);
            return;
        catch
        end

        try
            out = double(py.numpy.nditer(x));
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

    % dict Python
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

    % list / tuple
    if strcmp(cls, 'py.list') || strcmp(cls, 'py.tuple')
        c = cell(x);
        out = cell(size(c));
        for i = 1:numel(c)
            out{i} = make_matlab_saveable_recursive(c{i});
        end
        return;
    end

    % scalaire convertible
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

    % sinon on jette
    out = [];
end