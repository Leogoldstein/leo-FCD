function [true_env_paths, TSeriesPaths, env_paths_all, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(selectedFolders)
    % Initialize cell arrays to store paths
    true_env_paths = {};
    env_paths_all = {};
    statPaths = {};
    FPaths = {};
    iscellPaths = {};
    opsPaths = {};
    spksPaths = {};
    TSeriesPaths = {};  % Initialize the TSeriesPaths array

    for idx = 1:length(selectedFolders)
        selectedFolder = selectedFolders{idx};
        
        TSeriesFolder = dir(fullfile(selectedFolder, 'TSeries*'));
        
        if isscalar(TSeriesFolder) && TSeriesFolder(1).isdir
            % If there is only one 'TSeries' folder, automatically select it
            TSeriesPath = fullfile(selectedFolder, TSeriesFolder(1).name);
            
            suite2pFolder = fullfile(selectedFolder, 'suite2p');
            
            % If 'suite2p' subfolder exists, append it to the selected folder
            if exist(suite2pFolder, 'dir') == 7
                selectedFolder = suite2pFolder;
            else
                disp('Error: No ''suite2p'' subfolder found. Skipping this folder.');
                continue;
            end
        else
            % If there are multiple 'TSeries' folders or none, prompt the user to select one
            TSeriesPath = uigetdir(selectedFolder, 'Select a TSeries folder');

            % Check if the user canceled the selection
            if isequal(TSeriesPath, 0)
                disp('User clicked Cancel. Skipping this folder.');
                continue;
            end
            
            % Check if the selected folder contains 'suite2p'
            if ~endsWith(TSeriesPath, 'suite2p')
                suite2pFolder = fullfile(selectedFolder, 'suite2p');
                
                % If 'suite2p' subfolder exists, append it to the selected folder
                if exist(suite2pFolder, 'dir') == 7
                    selectedFolder = suite2pFolder;
                else
                    disp('Error: No ''suite2p'' subfolder found. Skipping this folder.');
                    continue;  % Skip to the next iteration of the loop
                end
            end
        end
        
        % List 'plane' folders in suite2pFolder
        planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
        
        if isscalar(planeFolders) && planeFolders(1).isdir
            % If there is only one 'plane' folder, automatically select it
            selectedFolder = fullfile(suite2pFolder, planeFolders(1).name);
        else
            % If there are multiple 'plane' folders or none, prompt the user to select one
            selectedFolder = uigetdir(suite2pFolder, 'Select a plane folder');
            
            % Check if the user canceled the selection
            if isequal(selectedFolder, 0)
                disp('User clicked Cancel. Skipping this folder.');
                continue;
            end
        end
        
        % Construct the path to the .env file
        env_file = dir(fullfile(TSeriesPath, '*.env'));
        if isscalar(env_file) % Check if exactly one .env file is found
            env_path = fullfile(TSeriesPath, env_file.name); % Use the .env file found
            env_paths_all{end+1} = env_path; % Add to env_paths
        else
           env_path = ''; % Set to empty if no .env file is found or multiple files exist
           env_paths_all{end+1} = ''; % Add an empty entry for consistency
        end
        true_env_paths{end+1} = env_path;

        % Construct file paths
        stat_path = fullfile(selectedFolder, 'stat.npy');
        F_path = fullfile(selectedFolder, 'F.npy');
        iscell_path = fullfile(selectedFolder, 'iscell.npy');
        ops_path = fullfile(selectedFolder, 'ops.npy');
        spks_path = fullfile(selectedFolder, 'spks.npy');

        % Create a list of all file paths
        filePaths = {stat_path, F_path, iscell_path, ops_path, spks_path};
        
        % Check the existence of each file in the list
        filesExist = false;  % Initialize flag to check if any file exists
        
        for i = 1:length(filePaths)
            if exist(filePaths{i}, 'file') == 2
                filesExist = true;  % At least one file exists
                break;
            end
        end

        % If at least one file exists, store the TSeriesPath
        if filesExist
            TSeriesPaths{end+1} = TSeriesPath;  % Add TSeriesPath to the list
            % Add the paths to the corresponding lists
            statPaths{end+1} = filePaths{1};
            FPaths{end+1} = filePaths{2};
            iscellPaths{end+1} = filePaths{3};
            opsPaths{end+1} = filePaths{4};
            spksPaths{end+1} = filePaths{5};
        end
    end
end
