function dataFolders = organize_data_by_animal(SelectedFolders)
    
    % Initialize cell array to store directory paths
    dataFolders = {};
    
    % Define a pattern to match the date, optional mTor, and ani parts
    pattern_general = '(\d{4}-\d{2}-\d{2})-(mTor\d+)?-(ani\d+)';
    
    % Loop through each file path in SelectedFolders
    for k = 1:length(SelectedFolders)
        % Load the selected file path
        file_path = SelectedFolders{k};
        
        % Display the selected folder for debugging
        disp(['Selected folder: ' file_path]);
        
        % Check if the folder name matches the general pattern
        tokens = regexp(file_path, pattern_general, 'tokens');
        
        if ~isempty(tokens)
            % Extract parts from tokens
            date_part = tokens{1}{1};  % Date part
            mTor_part = tokens{1}{2}; % mTor part (can be empty)
            animal_part = tokens{1}{3}; % Animal ID part
            
            disp(['Original folder: ' file_path]);
            
            % Determine the target folder based on the presence of mTor_part
            if ~isempty(mTor_part) && contains(mTor_part, 'mTor', 'IgnoreCase', true)
                % If mTor_part is present, construct target folder path
                targetFolder = fullfile('D:\imaging', 'FCD', 'to processed', mTor_part, animal_part, date_part);
            else
                % If mTor_part is not present, place folder in CTRL
                targetFolder = fullfile('D:\imaging', 'CTRL', 'to processed', animal_part, date_part);
            end
            
            % Create the target folder if it doesn't exist
            if ~exist(targetFolder, 'dir')
                mkdir(targetFolder);
                disp(['Created new target folder: ' targetFolder]);
            end
            
            % Move the contents of the original folder to the target folder
            contents = dir(file_path);
            for item = contents'
                if ~strcmp(item.name, '.') && ~strcmp(item.name, '..')
                    source = fullfile(file_path, item.name);
                    target = fullfile(targetFolder, item.name);
                    movefile(source, target);
                    disp(['Moved: ' source ' to ' target]);
                end
            end
            
            % Optionally delete the original folder if empty
            rmdir(file_path, 's');
            
            % Store the final target folder path
            dataFolders{end+1} = targetFolder; 
        else
            % Handle the case where the folder name doesn't match the pattern
            warning(['Folder name does not match the expected pattern: ' file_path]);
        end
    end
end
