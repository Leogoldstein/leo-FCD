function [truedataFolders, env_paths] = find_Fall_folders(selectedFolders)
    % Initialize cell arrays to store paths and canceled indices
    truedataFolders = {};  
    env_paths = {};

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
            
            % Check for the 'suite2p' folder inside the TSeries folder
            suite2pFolder = fullfile(TSeriesPath, 'suite2p');
            
            % If 'suite2p' subfolder exists, use it
            if exist(suite2pFolder, 'dir') == 7
                selectedFolder = suite2pFolder;
            else
                disp('Error: No ''suite2p'' subfolder found in TSeries folder. Skipping this folder.');
                continue;  % Skip to the next iteration of the loop
            end
        else
            % If there are multiple 'TSeries' folders, prompt the user to select one
            TSeriesPath = uigetdir(selectedFolder, 'Select a TSeries folder');
            disp(TSeriesPath)
            
            % Check if the user canceled the selection
            if isequal(TSeriesPath, 0)
                disp(['User clicked Cancel for folder index: ' num2str(idx)]);
                continue; % Skip to the next iteration of the loop
            end
            
            % Check for the 'suite2p' folder inside the selected TSeries folder
            suite2pFolder = fullfile(TSeriesPath, 'suite2p');
            
            % If 'suite2p' subfolder exists, use it
            if exist(suite2pFolder, 'dir') == 7
                selectedFolder = suite2pFolder;
            else
                disp('Error: No ''suite2p'' subfolder found in TSeries folder. Skipping this folder.');
                continue;  % Skip to the next iteration of the loop
            end
        end
    
        disp(selectedFolder)
    
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

        % Construct the path to the .env file
        env_file = dir(fullfile(TSeriesPath, '*.env'));
        %if isscalar(env_file) % Check if exactly one .env file is found
            env_path = fullfile(TSeriesPath, env_file.name); % Use the .env file found
        %else
         %   env_path = ''; % Set to empty if no .env file is found or multiple files exist
        %end
        env_paths{end+1} = env_path;

        % Construct the path to Fall.mat
        file_path = fullfile(selectedFolder, 'Fall.mat');
        
        % Check if Fall.mat exists
        if exist(file_path, 'file') == 2
            truedataFolders{end+1} = file_path;  % Add the path to Fall.mat to the cell array
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
end