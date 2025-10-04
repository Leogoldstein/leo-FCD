function [F_unsorted, F, F_deconv, ops, stat, iscell] = load_data(workingFolder)

    % Determine file extension and check for .npy files
    [~, ~, ext] = fileparts(workingFolder);
    files = dir(fullfile(workingFolder, '*.npy'));

    if ~isempty(files)
        % Unpack .npy file paths
        newFPath = fullfile(workingFolder, 'F.npy');
        newSpksPath = fullfile(workingFolder, 'spks.npy');
        newStatPath = fullfile(workingFolder, 'stat.npy');
        newIscellPath = fullfile(workingFolder, 'iscell.npy');
        newOpsPath = fullfile(workingFolder, 'ops.npy');

        % Load .npy files
        F_unsorted = readNPY(newFPath);
        F_deconv_unsorted = readNPY(newSpksPath);
        iscell = readNPY(newIscellPath);

        % Call the Python function to load stats and ops
        try
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(newStatPath);
            ops = mod.read_npy_file(newOpsPath);
        catch ME
            error('Failed to call Python function: %s', ME.message);
        end
        
        % dict = stat{1};
        % disp(dict.keys())

        F_unsorted = F_unsorted(:, 1:36000);
        keepMask = iscell(:,1) > 0;  % garde seulement les vraies cellules
        F = double(F_unsorted(keepMask, :));
        F_deconv = double(F_deconv_unsorted(keepMask, :)); 
        iscell = iscell(keepMask, :);

        % ---- Gestion py.list vs MATLAB array ----
        if isa(stat, 'py.list')
            idx = find(keepMask);              
            stat = subset_pylist(stat, idx);           
        else
            stat = stat(keepMask);             
        end

    elseif strcmp(ext, '.mat')
        % Load .mat files
        data = load(workingFolder);

        % Extract data from .mat file
        F_unsorted = data.F;
        F_deconv_unsorted = data.spks;
        iscell = data.iscell;
        ops = data.ops;
        stat = data.stat;
        
        keepMask = iscell(:,1) > 0;
        F = double(F_unsorted(keepMask, :));
        F_deconv = double(F_deconv_unsorted(keepMask, :)); 
        iscell = iscell(keepMask, :);
        stat   = stat(keepMask);

    else
        error('Unsupported file type: %s', ext);
    end   
    
    % ---- SUPPRESSION DES CELLULES QUI TOMBENT À 0 ----
    rowsWithZero = any(F == 0, 2);

    % ---- Appliquer la suppression ----
    F(rowsWithZero, :) = [];
    F_deconv(rowsWithZero, :) = [];
    iscell(rowsWithZero, :) = [];

    if isa(stat, 'py.list')
        stat = subset_pylist(stat, find(~rowsWithZero));
    else
        stat(rowsWithZero) = [];
    end

    % ---- LOG ----
    fprintf('Suppression de %d cellules à cause de F==0.\n', ...
        sum(rowsWithZero));
end

function out = subset_pylist(pylist, idx)
    % subset_pylist : extrait certains éléments d'un py.list et les convertit en struct MATLAB
    %
    % Entrées :
    %   - pylist : liste Python (py.list) contenant des py.dict
    %   - idx    : indices MATLAB des éléments à garder (1-based)
    %
    % Sortie :
    %   - out : cell array MATLAB contenant des structs
    
    out = cell(1, numel(idx));   % Prépare un cell array vide
    for k = 1:numel(idx)
        % ⚠ Python est 0-based, MATLAB est 1-based
        py_idx = py.int(idx(k)-1);      
        dict = pylist{py_idx};   % Récupère le py.dict correspondant

        % ---- Récupération des clés du dict ----
        keys = cellfun(@char, cell(py.list(dict.keys())), 'UniformOutput', false);

        % ---- Conversion en struct MATLAB ----
        s = struct();
        for kk = 1:numel(keys)
            key = keys{kk};        % ex: 'xpix'
            value = dict{key};     % valeur associée à cette clé

            % Conversion selon le type Python
            if isa(value, 'py.list') || isa(value, 'py.tuple')
                % Convertir en vecteur MATLAB
                val = double(py.array.array('d', py.numpy.array(value)));
            elseif isa(value, 'py.dict')
                % (optionnel : récursif si tu veux garder des sous-structs)
                val = struct();
            else
                % Tentative de conversion simple
                try
                    val = double(value);
                catch
                    % Si impossible -> on garde brut
                    val = value;
                end
            end

            % Ajout du champ dans le struct MATLAB
            s.(key) = val;
        end
        out{k} = s;  % Sauvegarde dans la sortie
    end
end


