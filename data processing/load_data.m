function [F_unsorted, F, ops, stat, iscell] = load_data(workingFolder)

    % Determine file extension and check for .npy files
    [~, ~, ext] = fileparts(workingFolder);
    files = dir(fullfile(workingFolder, '*.npy'));

    if ~isempty(files)
        % Unpack .npy file paths
        newFPath = fullfile(workingFolder, 'F.npy');
        newStatPath = fullfile(workingFolder, 'stat.npy');
        newIscellPath = fullfile(workingFolder, 'iscell.npy');
        newOpsPath = fullfile(workingFolder, 'ops.npy');

        % Load .npy files
        F_unsorted = readNPY(newFPath);
        iscell = readNPY(newIscellPath);

        % Call the Python function to load stats and ops
        try
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(newStatPath);
            ops = mod.read_npy_file(newOpsPath);
        catch ME
            error('Failed to call Python function: %s', ME.message);
        end
        
        F_unsorted = F_unsorted(:, 1:36000);
        keepMask = iscell(:,1) > 0;  % garde seulement les vraies cellules
        F = double(F_unsorted(keepMask, :));  
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
        iscell = data.iscell;
        ops = data.ops;
        stat = data.stat;
        
        keepMask = iscell(:,1) > 0;
        F = double(F_unsorted(keepMask, :));  
        iscell = iscell(keepMask, :);
        stat   = stat(keepMask);

    else
        error('Unsupported file type: %s', ext);
    end   
    
    % ---- SUPPRESSION DES CELLULES QUI TOMBENT À 0 ----
    rowsWithZero = any(F == 0, 2);

    % ---- Appliquer la suppression ----
    F(rowsWithZero, :) = [];
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
    % Retourne un cell array MATLAB en sélectionnant certains éléments d'un py.list
    % Python est 0-based, MATLAB est 1-based
    out = cell(1, numel(idx));
    for k = 1:numel(idx)
        % Convertir en py.int en soustrayant 1 pour l'indexation 0-based Python
        py_idx = py.int(idx(k)-1);
        out{k} = pylist{py_idx};
    end
end
