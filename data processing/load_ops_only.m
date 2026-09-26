function ops = load_ops_only(suite2p_path)

    ops = [];

    % =============================================================
    % Localiser ops.npy
    % =============================================================

    if isempty(suite2p_path)
        return;
    end

    suite2p_path = ...
        char(string(suite2p_path));

    if isfolder(suite2p_path)

        ops_path = ...
            fullfile( ...
                suite2p_path, ...
                'ops.npy');

    elseif isfile(suite2p_path)

        [~, name, ext] = ...
            fileparts(suite2p_path);

        if strcmpi([name ext], 'ops.npy')
            ops_path = suite2p_path;
        else
            warning( ...
                'load_ops_only:InvalidPath', ...
                'Le fichier fourni n''est pas ops.npy : %s', ...
                suite2p_path);
            return;
        end

    else

        warning( ...
            'load_ops_only:MissingPath', ...
            'Chemin Suite2p introuvable : %s', ...
            suite2p_path);

        return;
    end


    if exist(ops_path, 'file') ~= 2

        warning( ...
            'load_ops_only:MissingOps', ...
            'ops.npy introuvable : %s', ...
            ops_path);

        return;
    end


    % =============================================================
    % Lecture directe avec NumPy
    % =============================================================

    try

        np = ...
            py.importlib.import_module( ...
                'numpy');

        np_data = ...
            np.load( ...
                ops_path, ...
                pyargs( ...
                    'allow_pickle', ...
                    true));

        % Suite2p sauvegarde normalement ops sous la forme
        % d'un ndarray 0-D contenant un dictionnaire Python.
        try

            py_ops = ...
                np_data.item();

        catch

            py_ops = ...
                np_data;
        end


        % =========================================================
        % Conversion Python -> MATLAB
        % =========================================================

        ops = ...
            python_to_matlab( ...
                py_ops);

    catch ME

        warning( ...
            'load_ops_only:ReadFailed', ...
            'Impossible de lire ops.npy : %s', ...
            ME.message);

        ops = [];
        return;
    end


    % =============================================================
    % Contrôle
    % =============================================================

    if ~isstruct(ops)

        warning( ...
            'load_ops_only:InvalidOps', ...
            'ops.npy n''a pas produit une structure MATLAB valide.');

        ops = [];
        return;
    end
end


% =================================================================
% Conversion récursive Python -> MATLAB
% =================================================================

function out = python_to_matlab(value)

    if isempty(value)

        out = [];
        return;
    end


    % =============================================================
    % Types MATLAB déjà convertis
    % =============================================================

    if isnumeric(value) || ...
            islogical(value) || ...
            ischar(value) || ...
            isstring(value)

        out = value;
        return;
    end


    % =============================================================
    % Python dict
    % =============================================================

    if isa(value, 'py.dict')

        out = struct();

        keys = ...
            cell( ...
                py.list( ...
                    value.keys()));

        for k = 1:numel(keys)

            key_py = ...
                keys{k};

            key = ...
                char(key_py);

            field_name = ...
                matlab.lang.makeValidName( ...
                    key);

            out.(field_name) = ...
                python_to_matlab( ...
                    value{key_py});
        end

        return;
    end


    % =============================================================
    % NumPy ndarray
    % =============================================================

    if isa(value, 'py.numpy.ndarray')

        % La conversion directe fonctionne pour beaucoup
        % de tableaux numériques.
        try

            out = ...
                double(value);

            return;

        catch
        end


        % Fallback : ndarray -> liste Python -> MATLAB.
        try

            value_list = ...
                value.tolist();

            out = ...
                python_to_matlab( ...
                    value_list);

            return;

        catch
        end


        out = [];
        return;
    end


    % =============================================================
    % Python list / tuple
    % =============================================================

    if isa(value, 'py.list') || ...
            isa(value, 'py.tuple')

        c = ...
            cell(value);

        converted = ...
            cell(size(c));

        for k = 1:numel(c)

            converted{k} = ...
                python_to_matlab( ...
                    c{k});
        end


        % Si tous les éléments sont des scalaires numériques,
        % reconstruire directement un vecteur MATLAB.
        if ~isempty(converted) && ...
                all( ...
                    cellfun( ...
                        @(x) isnumeric(x) && isscalar(x), ...
                        converted))

            try

                out = ...
                    cell2mat( ...
                        converted);

                return;

            catch
            end
        end

        out = converted;
        return;
    end


    % =============================================================
    % Scalars Python
    % =============================================================

    try

        out = ...
            double(value);

        return;

    catch
    end


    try

        out = ...
            logical(value);

        return;

    catch
    end


    try

        out = ...
            char(value);

        return;

    catch
    end


    out = [];
end