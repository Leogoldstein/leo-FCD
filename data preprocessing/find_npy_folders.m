function [statPaths, FPaths, iscellPaths, opsPaths, canceledIndices] = find_npy_folders(selectedFolders)
    % Initialize cell arrays to store paths
    statPaths = {};
    FPaths = {};
    iscellPaths = {};
    opsPaths = {};
    canceledIndices = []; % Initialize an empty array to store indices where the user canceled

    for idx = 1:length(selectedFolders)
        selectedFolder = selectedFolders{idx};
        
        % Check if the selected folder contains suite2p folder
        suite2pFolder = fullfile(selectedFolder, 'suite2p');

        if exist(suite2pFolder, 'dir') == 7
           selectedFolder = suite2pFolder;
        
        else 
            % Check if the selected folder contains 'TSeries'
            if ~contains(selectedFolder, 'TSeries')
                
                TSeriesFolder = dir(fullfile(selectedFolder, 'TSeries*'));
                
                if isscalar(TSeriesFolder) && TSeriesFolder(1).isdir
                    % If there is only one 'TSeries' folder, automatically select it
                    selectedFolder = fullfile(selectedFolder, TSeriesFolder(1).name);
                    
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
                    selectedFolder = uigetdir(selectedFolder, 'Select a TSeries folder');
                    
                    % Check if the user canceled the selection
                    if isequal(selectedFolder, 0)
                        disp('User clicked Cancel. Skipping this folder.');
                        canceledIndices(end+1) = idx; % Store the index of the canceled selection
                        disp(canceledIndices)
                        continue;
                    end
                    
                    % Check if the selected folder contains 'suite2p'
                    if ~endsWith(selectedFolder, 'suite2p')
                        
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
                canceledIndices(end+1) = idx; % Store the index of the canceled selection
                continue;
            end
        end

        % Construct file paths
        stat_path = fullfile(selectedFolder, 'stat.npy');
        F_path = fullfile(selectedFolder, 'F.npy');
        iscell_path = fullfile(selectedFolder, 'iscell.npy');
        ops_path = fullfile(selectedFolder, 'ops.npy');

        % Create a list of all file paths
        filePaths = {stat_path, F_path, iscell_path, ops_path};
        
        % Check the existence of each file in the list
        for i = 1:length(filePaths)
            if exist(filePaths{i}, 'file') == 2
                % Add the paths to the corresponding lists
                statPaths{end+1} = filePaths{1};
                FPaths{end+1} = filePaths{2};
                iscellPaths{end+1} = filePaths{3};
                opsPaths{end+1} = filePaths{4};
                break
            end
        end
    end
end
