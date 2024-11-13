function [dataFolders] = organize_data_by_animal(SelectedFolders)
    % Get the current timestamp
    daytime = datestr(now, 'yy_mm_dd_HH_MM_SS');
    
    % Initialize cell arrays to store directory paths and animal-date pairs
    dataFolders = {};  % Initialize as empty cell array
    directories = {};  % Initialize as empty cell array
    
    % Define a pattern to match the date, optional mTor, and ani parts
    pattern_general = '(\d{4}-\d{2}-\d{2})-(mTor\d+)?-(ani\d+)';  % Updated pattern with optional mTor
    
    % Loop through each file path in SelectedFolders
    for k = 1:length(SelectedFolders)
        % Load the selected file path
        file_path = SelectedFolders{k};
        
        % Display the selected folder for debugging
        disp(['Selected folder: ' file_path]);
        
        % Check if it matches the general pattern
        tokens = regexp(file_path, pattern_general, 'tokens');
        
        if ~isempty(tokens)
            % Extract 'date_part', 'mTor_part', and 'animal_part' from tokens
            date_part = tokens{1}{1};  % Date part
            mTor_part = tokens{1}{2};   % mTor part (can be empty)
            animal_part = tokens{1}{3}; % Animal ID part (e.g., ani1)
           
            disp(['Original folder: ' file_path]);
            
            % Determine the target folder based on the presence of mTor_part
            if ~isempty(mTor_part) && contains(mTor_part, 'mTor', 'IgnoreCase', true)
                % If mTor_part is present, construct target folder path with "FCD", mTor_part, animal_part, and date_part
                targetFolder = fullfile('D:\imaging', 'FCD', mTor_part, animal_part, date_part);
            else
                % If mTor_part is not present, place dataFolder in CTRL
                targetFolder = fullfile('D:\imaging', 'CTRL', animal_part, date_part);
            end

            % Create the dataFolder directory if it doesn't exist
            if ~exist(targetFolder, 'dir')
                mkdir(targetFolder);
                disp(['Created new dataFolder: ' targetFolder]);
            end
            
            % Move the contents of the original folder to the target folder
            % Get list of contents in the original folder
            contents = dir(file_path);
            
            % Loop through each item in the original folder
            for item = contents'
                if ~item.isdir && ~strcmp(item.name, '.') && ~strcmp(item.name, '..')
                    % Construct source and target paths
                    source = fullfile(original_folder_name, item.name);
                    target = fullfile(targetFolder, item.name);
                    
                    % Move the item to the target folder
                    movefile(source, target);
                    disp(['Moved file: ' source ' to ' target]);
                elseif item.isdir && ~strcmp(item.name, '.') && ~strcmp(item.name, '..')
                    % For directories, move the whole directory
                    source = fullfile(file_path, item.name);
                    target = fullfile(targetFolder, item.name);
                    movefile(source, target);
                    disp(['Moved directory: ' source ' to ' target]);
                end
            end
            
            % Optionally delete the original folder if it is empty
            rmdir(file_path, 's');  % 's' to remove all contents if the folder is empty
        end
        
        % Store the final dataFolder path
        dataFolders{end+1} = targetFolder;  % Store targetFolder in dataFolders
    end
end
