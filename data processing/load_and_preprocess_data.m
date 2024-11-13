function [all_F, all_DF, all_ops, stat_list, iscell_list] = load_and_preprocess_data(workingFolders, varargin)
    % Load and preprocess data from a batch of .npy or .mat files.
    % Input:
    % - truedataFolders: Cell array of folders to process.
    % - varargin: Optional arguments for .npy file paths.
    %   (varargin{1} = newFPaths, varargin{2} = newStatPaths, varargin{3} = newIscellPaths, varargin{4} = newOpsPaths)
    % Output:
    % - all_F: Cell array of raw data matrices.
    % - all_DF: Cell array of processed data matrices.
    % - all_ops: Cell array of ops structures.
    % - stat_list: Cell array of statistics from loaded files.
    % - iscell_list: Cell array indicating cell status.

    % Initialize cell arrays to store results
    all_F = cell(length(workingFolders), 1);
    all_DF = cell(length(workingFolders), 1);
    all_ops = cell(length(workingFolders), 1);
    stat_list = cell(length(workingFolders), 1);
    iscell_list = cell(length(workingFolders), 1);

    % Process each folder
    for k = 1:length(workingFolders)
        file_path = workingFolders{k};
        disp(file_path)

        % Determine file extension
        [~, ~, ext] = fileparts(file_path);
        files = dir(fullfile(file_path, '*.npy'));

        if ~isempty(files)
            if length(varargin) < 4
                error('For .npy files, newFPaths, newStatPaths, newIscellPaths, and newOpsPaths are required.');
            end
            
            % Unpack .npy file paths
            newFPaths = varargin{1};
            newStatPaths = varargin{2};
            newIscellPaths = varargin{3};
            newOpsPaths = varargin{4};
            
            % Load .npy files
            F = readNPY(newFPaths{k});
            iscell = readNPY(newIscellPaths{k});
            
            % Call the Python function
            try
                mod = py.importlib.import_module('python_function');
                stat = mod.read_npy_file(newStatPaths{k});
                ops = mod.read_npy_file(newOpsPaths{k});
            catch ME
                error('Failed to call Python function: %s', ME.message);
            end
            
            % Process data for .npy files
            DF = double(F(iscell(:,1) > 0, 1:36000));
            
            % Store results
            stat_list{k} = stat;
            iscell_list{k} = iscell;
        
        elseif strcmp(ext, '.mat')
            % Load .mat files
            data = load(file_path);
            
            % Extract data from .mat file
            F = data.F;
            iscell = data.iscell;
            ops = data.ops;
            stat = data.stat;  % Assuming stat is available in .mat file
            
            % Process data for .mat files
            DF = double(F(iscell(:,1) > 0, :));
            
            % Store results
            stat_list{k} = stat;
            iscell_list{k} = iscell;
        else
            error('Unsupported file type: %s', ext);
        end

        % Store processed results
        all_F{k} = F;
        all_DF{k} = preprocess_data(DF);
        all_ops{k} = ops;
    end
end


function DF = preprocess_data(DF)
    % Apply preprocessing steps to the data matrix DF.
    % Input:
    % - DF: Data matrix to be preprocessed.
    % Output:
    % - DF: Preprocessed data matrix.

    % Savitzky-Golay filter
    DF = sgolayfilt(DF', 3, 5)';

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
