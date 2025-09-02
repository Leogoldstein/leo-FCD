function camFolders = findCamFolders(datePaths)
    
    numFolders = length(datePaths);
    camFolders = cell(numFolders, 1);

    for k = 1:length(datePaths)
        dateFolder = datePaths{k};

        if ~isfolder(fullDatePath)
            continue;
        end

        camPath = fullfile(dateFolder, 'cam', 'Concatenated');
        cameraPath = fullfile(dateFolder, 'camera', 'Concatenated');

        if isfolder(camPath)
            camFolders{k} = camPath;
            fprintf('Found cam folder: %s\n', camPath);
        elseif isfolder(cameraPath)
            camFolders{k} = cameraPath;
            fprintf('Found camera folder: %s\n', cameraPath);
        else
            fprintf('No Camera images found in %s.\n', fullDatePath);
        end
    end
end
