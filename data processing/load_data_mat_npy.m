function [stat, iscell] = load_data_mat_npy(dataFolder)
    % Load and preprocess data from .mat or .npy files in a specified folder.
    % Input:
    % - dataFolder: Path to the folder containing the files.
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

        % Display a message indicating successful loading
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
end