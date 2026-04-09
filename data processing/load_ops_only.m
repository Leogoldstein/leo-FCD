function ops = load_ops_only(suite2p_path)

    ops = [];

    [~, ~, ext] = fileparts(suite2p_path);

    if isfolder(suite2p_path)

        ops_npy = fullfile(suite2p_path, 'ops.npy');
        ops_mat = fullfile(suite2p_path, 'ops.mat');

        if isfile(ops_mat)
            try
                S = load(ops_mat);
                if isfield(S, 'ops')
                    ops = make_matlab_saveable_recursive(S.ops);
                    return;
                end
            catch ME
                warning('load_ops_only:opsmat', ...
                    'Impossible de lire ops.mat (%s).', ME.message);
            end
        end

        if isfile(ops_npy)
            try
                mod = py.importlib.import_module('python_function');
                ops_py = mod.read_npy_file(ops_npy);
                ops = make_matlab_saveable_recursive(ops_py);
                return;
            catch ME
                warning('load_ops_only:opsnpy', ...
                    'Impossible de lire ops.npy (%s).', ME.message);
            end
        end

    elseif strcmpi(ext, '.mat') && isfile(suite2p_path)
        try
            S = load(suite2p_path);
            if isfield(S, 'ops')
                ops = make_matlab_saveable_recursive(S.ops);
                return;
            end
        catch ME
            warning('load_ops_only:matfile', ...
                'Impossible de lire le fichier mat (%s).', ME.message);
        end
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