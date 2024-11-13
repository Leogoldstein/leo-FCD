function [workingFolders, canceledIndices] = find_Fall_folders(selectedFolders)
    % Initialize cell arrays to store paths and canceled indices
    workingFolders = {};  
    canceledIndices = []; % To keep track of canceled selections

    % Loop through each selected folder
    for idx = 1:length(selectedFolders)
        selectedFolder = selectedFolders{idx};

        % If the selected folder ends with 'TSeries', handle it as a TSeries folder directly
        if contains(selectedFolder, 'TSeries')
            % Since it's already a TSeries folder, check for suite2p
            suite2pFolder = fullfile(selectedFolder, 'suite2p');
            
            % Check if 'suite2p' subfolder exists
            if exist(suite2pFolder, 'dir') == 7
                selectedFolder = suite2pFolder;
            else
                disp('Error: No ''suite2p'' subfolder found in the selected TSeries folder. Skipping this folder.');
                continue;  % Skip to the next iteration of the loop
            end
        else
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
                
                % Check if the user canceled the selection
                if isequal(TSeriesPath, 0)
                    disp(['User clicked Cancel for folder index: ' num2str(idx)]);
                    canceledIndices = [canceledIndices, idx]; % Record the canceled index
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
                canceledIndices = [canceledIndices, idx]; % Record the canceled index
                continue; % Skip to the next iteration of the loop
            end
        end
        
        % Construct the path to Fall.mat
        file_path = fullfile(selectedFolder, 'Fall.mat');
        
        % Check if Fall.mat exists
        if exist(file_path, 'file') == 2
            workingFolders{end+1} = file_path;  % Add the path to Fall.mat to the cell array
        else
            % If Fall.mat does not exist, display an error message
            disp(['Error: This folder does not contain a Fall.mat file. Folder: ' selectedFolder]);
        end
    end
    
    % Display the directories with Fall.mat files
    disp('Directories with Fall.mat files:');
    for i = 1:length(workingFolders)
        disp(workingFolders{i});
    end 
end
