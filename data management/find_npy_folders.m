function [true_xml_paths, TSeriesPaths, xml_paths_all, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(selectedFolders)
    % Initialize cell arrays to store paths
    numFolders = length(selectedFolders);
    true_xml_paths = cell(numFolders, 1);
    xml_paths_all = cell(numFolders, 1);
    statPaths = cell(numFolders, 1);
    FPaths = cell(numFolders, 1);
    iscellPaths = cell(numFolders, 1);
    opsPaths = cell(numFolders, 1);
    spksPaths = cell(numFolders, 1);
    TSeriesPaths = cell(numFolders, 1);  % Initialize the TSeriesPaths array

    for idx = 1:numFolders
        selectedFolder = selectedFolders{idx};
        
        TSeriesFolder = dir(fullfile(selectedFolder, 'TSeries*'));
        
        if isscalar(TSeriesFolder) && TSeriesFolder(1).isdir
            % If there is only one 'TSeries' folder, automatically select it
            TSeriesPath = fullfile(selectedFolder, TSeriesFolder(1).name);
            
            suite2pFolder1 = fullfile(selectedFolder, 'suite2p');
            suite2pFolder2 = fullfile(TSeriesPath, 'suite2p');
            
            if exist(suite2pFolder1, 'dir') == 7
                suite2pFolder = suite2pFolder1;
            elseif exist(suite2pFolder2, 'dir') == 7
                suite2pFolder = suite2pFolder2;
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
                if ~exist(suite2pFolder, 'dir') == 7
                    disp('Error: No ''suite2p'' subfolder found. Skipping this folder.');
                    continue;  % Skip to the next iteration of the loop
                end
            end
        end
        
        % List 'plane' folders in suite2pFolder
        planeFolders = dir(fullfile(suite2pFolder, 'plane*')); 
        
        if isscalar(planeFolders) && planeFolders(1).isdir
            % If there is only one 'plane' folder, automatically select it
            planeFolder = fullfile(suite2pFolder, planeFolders(1).name);
        else
            % If there are multiple 'plane' folders or none, prompt the user to select one
            planeFolder = uigetdir(suite2pFolder, 'Select a plane folder');
            
            % Check if the user canceled the selection
            if isequal(planeFolder, 0)
                disp('User clicked Cancel. Skipping this folder.');
                continue;
            end
        end
        
        % Construct the path to the .xml file
        xml_file = dir(fullfile(TSeriesPath, '*.xml'));
        if isscalar(xml_file) % Check if exactly one .xml file is found
            xml_path = fullfile(TSeriesPath, xml_file.name); % Use the .xml file found
            xml_paths_all{idx} = xml_path; % Add to xml_paths
        else
           xml_path = ''; % Set to empty if no .xml file is found or multiple files exist
           xml_paths_all{idx} = ''; % Add an empty entry for consistency
        end
        true_xml_paths{idx} = xml_path;

        % Construct file paths
        stat_path = fullfile(planeFolder, 'stat.npy');
        F_path = fullfile(planeFolder, 'F.npy');
        iscell_path = fullfile(planeFolder, 'iscell.npy');
        ops_path = fullfile(planeFolder, 'ops.npy');
        spks_path = fullfile(planeFolder, 'spks.npy');

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
            TSeriesPaths{idx} = TSeriesPath;  % Add TSeriesPath to the list
            % Add the paths to the corresponding lists
            statPaths{idx} = filePaths{1};
            FPaths{idx} = filePaths{2};
            iscellPaths{idx} = filePaths{3};
            opsPaths{idx} = filePaths{4};
            spksPaths{idx} = filePaths{5};
        end
    end
end
