function masks_mat = load_masks_from_cellpose(path)
    % Function to load the masks from a Cellpose output file in a given directory
    % path: Path to the directory containing the .npy files.
    
    % List all .npy files in the directory
    npy_files = dir(fullfile(path, '*.npy'));
    
    % Check if any .npy file exists
    if ~isempty(npy_files)
        % Construct the full path of the first .npy file
        npy_file_path = fullfile(npy_files(1).folder, npy_files(1).name);
        
        % Use readNPY to read the file (requires npy-matlab library)
        mod = py.importlib.import_module('python_function');
        image = mod.read_npy_file(npy_file_path);           
        
        % Extract the 'masks' key
        keys = image.keys();  % Get the keys of the dictionary
        keys_list = cellfun(@char, cell(py.list(keys)), 'UniformOutput', false);  % Convert to MATLAB cell array of strings
        
        if ismember('masks', keys_list)  % Check if 'masks' key exists
            masks = image{'masks'};  % Access the 'masks' key
            masks_mat = double(py.numpy.array(masks));  % Convert to MATLAB array
            
            % Remove NaN values by setting them to zero (or any other value)
            masks_mat(isnan(masks_mat)) = 0;  % You can replace NaN with 0 or any other number
        else
            error('Key "masks" not found in the Python dictionary.');
        end
    else
        error('No .npy files found in the specified directory.');
    end
end
