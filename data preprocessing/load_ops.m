function all_ops = load_ops(current_folders_group)

    % Initialize output variables
    numFolders = length(current_folders_group);
    all_ops = cell(numFolders, 1);

    % Loop through each working folder
    for m = 1:numFolders
        try
            % Get the current folder path
            current_folder = current_folders_group{m};

            % Determine file extension and check for .npy files
            [~, ~, ext] = fileparts(current_folder);
            files = dir(fullfile(current_folder, '*.npy'));

            if ~isempty(files)
                % Unpack .npy file paths
                newOpsPath = fullfile(current_folder, 'ops.npy');
                disp(newOpsPath)

                % Call the Python function to load stats and ops
                try
                    mod = py.importlib.import_module('python_function');
                    ops = mod.read_npy_file(newOpsPath);
                catch ME
                    error('Failed to call Python function: %s', ME.message);
                end

            elseif strcmp(ext, '.mat')
                % Load .mat files
                data = load(current_folder);
                ops = data.ops;
            else
                error('Unsupported file type: %s', ext);
            end

            % Append data to output variables
            all_ops{m} = ops;
            
        catch ME
            % Handle any errors related to the current folder and continue the loop
            disp(ME.message);
            continue;  % Continue to the next folder in the loop
        end
    end
end
