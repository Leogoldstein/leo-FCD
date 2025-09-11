function [stat, iscell] = load_data_mat_npy(dataFolder, badIdx)
    % Load and preprocess data from .mat or .npy files in a specified folder.
    %
    % Input:
    % - dataFolder: Path to the folder containing the files.
    % - badIdx: indices des cellules à supprimer (par rapport à iscell/stat)
    %
    % Output:
    % - stat: Structure or data array loaded from stat.npy or .mat file.
    % - iscell: Array indicating cell status from iscell.npy or .mat file.

    iscell = [];
    stat = [];

    % Determine file extension
    [~, ~, ext] = fileparts(dataFolder);
    npy_file = dir(fullfile(dataFolder, '*.npy'));

    if strcmp(ext, '.mat')

        % Load data from .mat files (if available)
        data = load(dataFolder);

        % Extract and store the specific variables
        if isfield(data, 'iscell')
            iscell = data.iscell;
        else
            warning(['Variable "iscell" not found in: ' dataFolder]);
        end

        if isfield(data, 'stat')
            stat = data.stat;
        else
            warning(['Variable "stat" not found in: ' dataFolder]);
        end

        disp(['Loaded data from: ' dataFolder]);

    elseif ~isempty(npy_file)

        % Define paths for .npy files
        statPath = fullfile(dataFolder, 'stat.npy');
        iscellPath = fullfile(dataFolder, 'iscell.npy');

        iscell = readNPY(iscellPath);
        try
            % Load data from .npy files
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(statPath);
            disp('Loaded data from .npy files.');
        catch ME
            error('Failed to load .npy files: %s', ME.message);
        end
        
    else
        error('Unsupported file type: %s', ext);
    end

    if nargin > 1 && ~isempty(badIdx)
        % Vérifie que les indices sont valides
        badIdx = badIdx(badIdx >= 1 & badIdx <= size(iscell,1));

        if ~isempty(badIdx)
            % Supprimer dans iscell
            iscell(badIdx,:) = [];

            % Supprimer dans stat
            if isa(stat, 'py.list')
                keepIdx = setdiff(1:size(iscell,1)+numel(badIdx), badIdx); 
                stat = subset_pylist(stat, keepIdx);
            else
                stat(badIdx) = [];
            end

            fprintf('Suppression de %d cellules via badIdx.\n', numel(badIdx));
        end
    end
end

function out = subset_pylist(pylist, idx)
    % Retourne un cell array MATLAB en sélectionnant certains éléments d'un py.list
    % Python est 0-based, MATLAB est 1-based
    out = cell(1, numel(idx));
    for k = 1:numel(idx)
        py_idx = py.int(idx(k)-1);
        out{k} = pylist{py_idx};
    end
end
