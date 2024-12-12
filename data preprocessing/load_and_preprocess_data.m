function [F, DF, ops, stat, iscell] = load_and_preprocess_data(workingFolder)
    % Load and preprocess data from a single folder of .npy or .mat files.
    % Input:
    % - workingFolder: Folder to process.
    % - varargin: Optional arguments for .npy file paths.
    %   (varargin{1} = newFPaths, varargin{2} = newStatPaths, varargin{3} = newIscellPaths, varargin{4} = newOpsPaths)
    % Output:
    % - all_F: Raw data matrix.
    % - all_DF: Processed data matrix.
    % - all_ops: ops structure.
    % - stat_list: Statistics from loaded files.
    % - iscell_list: Cell status.

    % Process the folder
    disp(workingFolder)

    % Determine file extension and check for .npy files
    [~, ~, ext] = fileparts(workingFolder);
    files = dir(fullfile(workingFolder, '*.npy'));

    if ~isempty(files)

        % Unpack .npy file paths
        newFPath = fullfile(workingFolder, 'F.npy');
        newStatPath = fullfile(workingFolder, 'stat.npy');
        newIscellPath = fullfile(workingFolder, 'iscell.npy');
        newOpsPath = fullfile(workingFolder, 'ops.npy');
        newSpksPath = fullfile(workingFolder, 'spks.npy');

        % Load .npy files
        F = readNPY(newFPath);  % Assuming only one folder, so the 1st entry is used
        iscell = readNPY(newIscellPath);

        % Call the Python function to load stats and ops
        try
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(newStatPath);
            ops = mod.read_npy_file(newOpsPath);
            ops = dictionary(ops);
        catch ME
            error('Failed to call Python function: %s', ME.message);
        end

        % Process data for .npy files
        DF = double(F(iscell(:,1) > 0, 1:36000));  % Assuming the processing size

    elseif strcmp(ext, '.mat')
        % Load .mat files
        data = load(workingFolder);

        % Extract data from .mat file
        F = data.F;
        iscell = data.iscell;
        ops = data.ops;
        stat = data.stat;  % Assuming stat is available in .mat file

        % Process data for .mat files
        DF = double(F(iscell(:,1) > 0, :));
    else
        error('Unsupported file type: %s', ext);
    end

    DF = preprocess_data(DF);
end


function DF = preprocess_data(DF)
    % Apply preprocessing steps to the data matrix DF.
    % Input:
    % - DF: Data matrix to be preprocessed.
    % Output:
    % - DF: Preprocessed data matrix.

    % Savitzky-Golay filter
    DF = sgolayfilt(DF', 3, 5)' ;

    [NCell, Nz] = size(DF);
    disp(['Ncells = ' num2str(NCell)]);

    % Bleaching correction
    ws = warning('off', 'all');
    for i = 1:NCell
        p0 = polyfit(1:Nz, DF(i,:), 3);
        DF(i,:) = DF(i,:) ./ polyval(p0, 1:Nz);
    end
    warning(ws);

    % Median normalization
    DF = DF ./ median(DF, 2);
end