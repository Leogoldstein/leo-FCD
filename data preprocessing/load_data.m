function [F, DF, ops, stat, iscell] = load_data(workingFolder)

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
        F = readNPY(newFPath);
        iscell = readNPY(newIscellPath);

        % Call the Python function to load stats and ops
        try
            mod = py.importlib.import_module('python_function');
            stat = mod.read_npy_file(newStatPath);
            ops = mod.read_npy_file(newOpsPath);
        catch ME
            error('Failed to call Python function: %s', ME.message);
        end
        
        F = F(:, 1:36000);
        DF = double(F(iscell(:,1) > 0, :));  

    elseif strcmp(ext, '.mat')
        % Load .mat files
        data = load(workingFolder);

        % Extract data from .mat file
        F = data.F;
        iscell = data.iscell;
        ops = data.ops;
        stat = data.stat;  % Assuming stat is available in .mat file
        
        DF = double(F(iscell(:,1) > 0, :));  
    else
        error('Unsupported file type: %s', ext);
    end   
end