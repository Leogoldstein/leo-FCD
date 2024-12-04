function [stat, iscell] = load_data_mat_npy(dataFolder)
    % Load and preprocess data from .mat or .npy files in a specified folder.
    % Input:
    % - dataFolder: Path to the folder containing the files.
    % Output:
    % - stat: Structure or data array loaded from stat.npy or .mat file.
    % - iscell: Array indicating cell status from iscell.npy or .mat file.

    % Define paths for .npy files
    statPath = fullfile(dataFolder, 'stat.npy');
    iscellPath = fullfile(dataFolder, 'iscell.npy');
    matFiles = dir(fullfile(dataFolder, '*.mat'));

    % Initialize outputs
    stat = [];
    iscell = [];

    % Check if .npy files exist
    if isfile(statPath) && isfile(iscellPath)
        try
            % Load data from .npy files
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(statPath);
            iscell = mod.read_npy_file(iscellPath);
            disp('Loaded data from .npy files.');
        catch ME
            error('Failed to load .npy files: %s', ME.message);
        end
    elseif ~isempty(matFiles)
        % Load data from .mat files (if available)
        for k = 1:length(matFiles)
            matData = load(fullfile(dataFolder, matFiles(k).name));
            if isfield(matData, 'stat')
                stat = matData.stat;
            end
            if isfield(matData, 'iscell')
                iscell = matData.iscell;
            end
        end
        if isempty(stat) || isempty(iscell)
            warning('Some variables are missing in .mat files.');
        else
            disp('Loaded data from .mat files.');
        end
    else
        error('No valid .npy or .mat files found in the specified folder.');
    end
end
