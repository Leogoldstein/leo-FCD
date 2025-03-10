function [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(selectedFolders)
    numFolders = length(selectedFolders);
    TseriesFolders = cell(numFolders, 4);
    TSeriesPaths = cell(numFolders, 4);
    true_env_paths = cell(numFolders, 1);
    lastFolderNames = cell(numFolders, 4);

    for idx = 1:numFolders
        selectedFolder = selectedFolders{idx};
        if ~isfolder(selectedFolder)
            disp(['Warning: Folder does not exist: ', selectedFolder]);
            continue;
        end
        
        TSeriesFoldersList = dir(fullfile(selectedFolder, 'TSeries*'));
        if isempty(TSeriesFoldersList)
            disp(['No TSeries folders found in folder: ', selectedFolder, '. Skipping.']);
            continue;
        end
        
        TSeriesPathsTemp = {'' '' '' ''};
        labels = {'Gcamp', 'Red', 'Blue', 'Green'};
        foundFolders = {{} {} {} {}};
        
        for i = 1:length(TSeriesFoldersList)
            folderName = TSeriesFoldersList(i).name;
            fullPath = fullfile(selectedFolder, folderName);
            matched = false;
            
            for k = 1:length(labels)
                if contains(lower(folderName), lower(labels{k}))
                    foundFolders{k}{end+1} = fullPath;
                    matched = true;
                end
            end
            
            if ~matched
                foundFolders{1}{end+1} = fullPath;
            end
        end
        
        for k = 1:length(labels)
            if ~isempty(foundFolders{k})
                TSeriesPathsTemp{k} = foundFolders{k}{1};
            end
        end
        
        TSeriesPaths(idx, :) = TSeriesPathsTemp;
        
        for k = 1:length(TSeriesPathsTemp)
            if ~isempty(TSeriesPathsTemp{k})
                [~, lastFolderName] = fileparts(TSeriesPathsTemp{k});
                lastFolderNames{idx, k} = lastFolderName;
            else
                lastFolderNames{idx, k} = '';
            end
        end
        
        if ~isempty(TSeriesPaths{idx, 3})
            blueFolder = fullfile(TSeriesPaths{idx, 3}, 'Blue');
            greenFolder = fullfile(TSeriesPaths{idx, 3}, 'Green');
            
            if ~exist(blueFolder, 'dir')
                mkdir(blueFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch3*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), fullfile(blueFolder, tiffFiles(j).name));
                end
            end
            
            if ~exist(greenFolder, 'dir')
                mkdir(greenFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch2*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), fullfile(greenFolder, tiffFiles(j).name));
                end
            end
            
            TSeriesPaths{idx, 3} = blueFolder;
            TSeriesPaths{idx, 4} = greenFolder;
        end
        
        if ~isempty(TSeriesPaths{idx, 1})
            [env_paths_all, env_path] = processEnvFile(TSeriesPaths{idx, 1});
        else
            env_path = '';
        end
        
        true_env_paths{idx} = env_path;
        
        dataFolders = {'' '' '' ''};
        for j = 1:4
            currentPath = TSeriesPaths{idx, j};
            if ~isempty(currentPath)
                dataFolder = process_TSeries(currentPath);
                if ~isempty(dataFolder)
                    dataFolders{j} = dataFolder;
                end
            end
        end
        
        TseriesFolders(idx, :) = dataFolders;
        
        if ~isempty(dataFolders{1})
            file_path = fullfile(dataFolders{1}, 'Fall.mat');
            if exist(file_path, 'file') == 2
                TseriesFolders{idx, 1} = file_path;
            else
                TseriesFolders{idx, 1} = '';
                disp(['Error: No Fall.mat found in folder: ', dataFolders{1}]);
            end
        end
    end
end

function [env_paths_all, env_path] = processEnvFile(TSeriesPathGcamp)
    env_file = dir(fullfile(TSeriesPathGcamp, '*.env'));
    env_paths_all = {};
    
    if ~isempty(env_file)
        env_path = fullfile(TSeriesPathGcamp, env_file(1).name);
        env_paths_all{end+1} = env_path;
    else
        disp(['Warning: No .env file found in GCaMP folder: ', TSeriesPathGcamp]);
        env_path = '';
        env_paths_all{end+1} = '';
    end
end

function dataFolder = process_TSeries(TSeriesPath)
    suite2pFolder = fullfile(TSeriesPath, 'suite2p');
    if ~isfolder(suite2pFolder)
        disp(['Error: No ''suite2p'' folder found in ', TSeriesPath, '. Skipping processing.']);
        dataFolder = '';
        return;
    end
    
    planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
    if isempty(planeFolders)
        disp(['Error: No ''plane'' folder found in ', suite2pFolder, '. Skipping processing.']);
        dataFolder = '';
        return;
    end
    
    if isscalar(planeFolders) && planeFolders(1).isdir
        dataFolder = fullfile(suite2pFolder, planeFolders(1).name);
    else
        dataFolder = uigetdir(suite2pFolder, 'Select a plane folder');
        if dataFolder == 0
            disp(['User clicked Cancel for folder: ', TSeriesPath]);
            dataFolder = '';
            return;
        end
    end
end
