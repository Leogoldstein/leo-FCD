function [truedataFolders, env_paths, env_paths_all] = find_Fall_folders(selectedFolders)
    % Initialize cell arrays to store paths and canceled indices
    truedataFolders = {};  
    env_paths = {};
    env_paths_all = {};

    % Loop through each selected folder
    for idx = 1:length(selectedFolders)
        selectedFolder = selectedFolders{idx};
       
        % Check for 'TSeries' folders in the selected directory
        TSeriesFolders = dir(fullfile(selectedFolder, 'TSeries*'));

        % Handle cases based on the number of TSeries folders found
        if isempty(TSeriesFolders)
            disp('No TSeries folders found. Skipping this folder.');
            continue;  % Skip to the next iteration if none found
        elseif isscalar(TSeriesFolders) && TSeriesFolders(1).isdir
            % If there is only one 'TSeries' folder, select it automatically
            TSeriesPath = fullfile(selectedFolder, TSeriesFolders(1).name);
        else
            % If there are multiple 'TSeries' folders, prompt the user to select one
            TSeriesPath = uigetdir(selectedFolder, 'Select a TSeries folder');

            % Check if the user canceled the selection
            if isequal(TSeriesPath, 0)
                disp(['User clicked Cancel for folder index: ' num2str(idx)]);
                continue; % Skip to the next iteration of the loop
            end
        end

        % Always process the .env file if it exists, even if no suite2p folder is found
        env_file = dir(fullfile(TSeriesPath, '*.env'));
        if ~isempty(env_file)
            % If a .env file exists, construct its full path
            env_path = fullfile(TSeriesPath, env_file(1).name); 
            env_paths_all{end+1} = env_path; % Add to env_paths
        else
            disp(['Warning: No .env file found in TSeries folder: ' TSeriesPath]);
            env_paths_all{end+1} = ''; % Add an empty entry for consistency
        end

        % Check for the 'suite2p' folder inside the TSeries folder
        suite2pFolder = fullfile(TSeriesPath, 'suite2p');
        
        % If 'suite2p' subfolder exists, use it
        if exist(suite2pFolder, 'dir') == 7
            selectedFolder = suite2pFolder;
        else
            disp('Error: No ''suite2p'' subfolder found in TSeries folder. Skipping Fall.mat processing.');
            continue;  % Skip to the next iteration of the loop, but .env is already processed
        end
    
        % List 'plane' folders in suite2pFolder
        planeFolders = dir(fullfile(selectedFolder, 'plane*'));
        
        if isscalar(planeFolders) && planeFolders(1).isdir
            % If there is only one 'plane' folder, select it automatically
            selectedFolder = fullfile(selectedFolder, planeFolders(1).name);
        else
            % If there are multiple 'plane' folders or none, prompt the user to select one
            selectedFolder = uigetdir(selectedFolder, 'Select a plane folder');
            
            % Check if the user canceled the selection
            if isequal(selectedFolder, 0)
                disp(['User clicked Cancel for folder index: ' num2str(idx)]);
                continue; % Skip to the next iteration of the loop
            end
        end

        % Construct the path to Fall.mat
        file_path = fullfile(selectedFolder, 'Fall.mat');
        
        % Check if Fall.mat exists
        if exist(file_path, 'file') == 2
            truedataFolders{end+1} = file_path;  % Add the path to Fall.mat to the cell array
            env_paths{end+1} = env_path;
        else
            % If Fall.mat does not exist, display an error message
            disp(['Error: This folder does not contain a Fall.mat file. Folder: ' selectedFolder]);
        end
    end
    
    % Display the directories with Fall.mat files
    disp('Directories with Fall.mat files:');
    for i = 1:length(truedataFolders)
        disp(truedataFolders{i});
    end
    
    % Display the .env file paths
    % disp('Paths to .env files:');
    % for i = 1:length(env_paths)
    %     disp(env_paths{i});
    % end
end
