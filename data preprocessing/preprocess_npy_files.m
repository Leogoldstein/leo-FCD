function [newFPaths, newStatPaths, newIscellPaths, newOpsPaths, newSpksPaths, truedataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder)
    % Remove empty entries from input paths
    FPaths = FPaths(~cellfun('isempty', FPaths));
    statPaths = statPaths(~cellfun('isempty', statPaths));
    iscellPaths = iscellPaths(~cellfun('isempty', iscellPaths));
    opsPaths = opsPaths(~cellfun('isempty', opsPaths));
    spksPaths = spksPaths(~cellfun('isempty', spksPaths));

    % Store all path variables in a cell array
    allPaths = {FPaths, statPaths, iscellPaths, opsPaths, spksPaths};  % Added spksPaths

    % Initialize a cell array to store the paths of directories (both new and existing)
    allFolders = {}; % This will store the directories in a row format initially

    % Initialize new path variables to store the new paths
    newFPaths = cell(size(FPaths));
    newStatPaths = cell(size(statPaths));
    newIscellPaths = cell(size(iscellPaths));
    newOpsPaths = cell(size(opsPaths));
    newSpksPaths = cell(size(spksPaths));  % Added newSpksPaths

    % Loop through each set of paths
    for setIdx = 1:length(allPaths)
        % Get the current set of paths
        currentPaths = allPaths{setIdx};
        
        % Determine which variable to update based on setIdx
        switch setIdx
            case 1
                newPaths = newFPaths;
            case 2
                newPaths = newStatPaths;
            case 3
                newPaths = newIscellPaths;
            case 4
                newPaths = newOpsPaths;
            case 5  % Added case for spksPaths
                newPaths = newSpksPaths;
        end

        % Loop through each file path in the current set
        for k = 1:length(currentPaths)
            % Load the selected file
            file_path = currentPaths{k};
            
            % Extract the date (e.g., '2024-04-30') and animal identifier (e.g., 'jm038') from the file path
            date = regexp(file_path, '\d{4}-\d{2}-\d{2}', 'match', 'once');
            animal = regexp(file_path, '(?<=[\\/])jm\d+', 'match', 'once');
            
            % Create the directory path for saving analysis
            namefull = fullfile(destinationFolder, animal, date);
            
            % Store the path of the directory (whether new or existing)
            allFolders{end+1} = namefull;
            
            if ~exist(namefull, 'dir')  % Check if the directory exists
                mkdir(namefull);  % Make the directory if it does not exist
                disp(['Created new folder: ' namefull]);
            end
            
            % Extract file name and extension
            [~, fileName, fileExt] = fileparts(file_path);
            
            % Define destination file path
            destinationFilePath = fullfile(namefull, [fileName, fileExt]);
            
            % Check if the file already exists at the destination
            if ~exist(destinationFilePath, 'file')
                % Copy the file to the destination folder if it doesn't already exist
                copyfile(file_path, destinationFilePath);
                disp(['Copied ' file_path ' to ' destinationFilePath]);
            else
                disp(['File already exists at destination: ' destinationFilePath]);
            end
            
            % Update the corresponding new path variable
            newPaths{k} = destinationFilePath;
        end
        
        % Save the updated newPaths back to the appropriate variable
        switch setIdx
            case 1
                newFPaths = newPaths;
            case 2
                newStatPaths = newPaths;
            case 3
                newIscellPaths = newPaths;
            case 4
                newOpsPaths = newPaths;
            case 5  % Save the updated paths for newSpksPaths
                newSpksPaths = newPaths;
        end
    end

    % Get the unique directories and ensure it's in a column format
    truedataFolders = unique(allFolders)'; % The transpose ensures it is 1xN row, now transpose to 7x1 column

    % Display the unique directories
    disp('Directories with npy files:');
    for i = 1:length(truedataFolders)
        disp(truedataFolders{i});
    end
end
