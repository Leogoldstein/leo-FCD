function [daytime, directories, animal_date_list] = create_directories_for_analysis(dataFolders, PathSave)
    % Get the current timestamp
    daytime = datestr(now, 'yy_mm_dd_HH_MM_SS');
    
    % Initialize cell arrays to store directory paths and animal-date pairs
    directories = cell(length(dataFolders), 1);
    animal_date_list = cell(length(dataFolders), 2);
    
    % Define patterns for .npy and .mat files
    pattern_general = 'imaging\\([^\\]+)\\([^\\]+)?\\([^\\]+)\\([^\\]+)\\([^\\]+)';
    pattern_npy = 'D:\\imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)';  % New pattern for .npy files
    
    % Loop through each file path in dataFolders
    for k = 1:length(dataFolders)
        % Load the selected file path
        file_path = dataFolders{k};
      
        % Check if the file path matches pattern_general or pattern_npy
        tokens = regexp(file_path, pattern_general, 'tokens');
        if isempty(tokens)
            tokens = regexp(file_path, pattern_npy, 'tokens');
        end
        
        if ~isempty(tokens)
            % Extract 'type_part', 'mTor_part', 'animal_part', and 'date_part' from tokens
            if length(tokens{1}) == 5
                % Matching pattern_general
                type_part = tokens{1}{1}; % Example: FCD
                group_part = tokens{1}{2};  % Example: mTor13
                animal_part = tokens{1}{3}; % Example: ani2
                date_part = tokens{1}{4}; % Example: 2024-10-22
            else
                % Matching pattern_npy
                type_part = tokens{1}{1}; % Example: jm
                group_part = ''; % No 'group_part' from the new pattern
                animal_part = tokens{1}{2}; % Example: jm040
                date_part = tokens{1}{3}; % Example: 2024-05-06
            end

            % Store the extracted parts in animal_date_list
            animal_date_list{k, 1} = type_part;
            animal_date_list{k, 2} = group_part ;
            animal_date_list{k, 3} = animal_part;
            animal_date_list{k, 4} = date_part;
            
            % Construct the full directory path
            if ~isempty(group_part)
                directory = fullfile(PathSave, type_part, group_part, animal_part, date_part, daytime);
            else
                directory = fullfile(PathSave, type_part, animal_part, date_part, daytime);
            end
            
            % Create the directory if it does not exist
            if ~exist(directory, 'dir')
                mkdir(directory);
                disp(['Created new folder: ' directory]);
            end
            
            % Store the directory path
            directories{k} = directory;
            dataFolder = dataFolders{1,k};

            % Save the paths.mat file with directory and dataFolder
            save(fullfile(directories{k}, 'paths.mat'), 'directory', 'dataFolder'); 

        else
            disp(['No match found for path: ' file_path]);
        end
    end
    
    % Assign ages to the animals
    animal_date_list = assign_age_to_animals(animal_date_list);
    
    % Save animal_date_list information into each directory's paths.mat
    for k = 1:length(directories)
        animal_date_list_k{1,1} = animal_date_list{k,1};
        animal_date_list_k{1,2} = animal_date_list{k,2};
        animal_date_list_k{1,3} = animal_date_list{k,3};
        animal_date_list_k{1,4} = animal_date_list{k,4};
        animal_date_list_k{1,5} = animal_date_list{k,5};
        
        % Append to the existing paths.mat file
        save(fullfile(directories{k}, 'paths.mat'), 'animal_date_list_k', '-append');
    end
end

function animal_date_list = assign_age_to_animals(animal_date_list)
    % assign_age_to_animals prompts the user to assign an age to each unique animal in each unique group
    % 
    % Arguments:
    % animal_date_list - List of animal dates with 4 columns (type, group, animal, date)

    % Identify unique groups and animals
    unique_groups = unique(animal_date_list(:, 2));
    
    % Loop over each unique group
    for g = 1:length(unique_groups)
        group = unique_groups{g};
        group_indices = strcmp(animal_date_list(:, 2), group);
        
        % Find unique animals within this group
        unique_animals_in_group = unique(animal_date_list(group_indices, 3));
        
        % Loop over each unique animal within the group
        for a = 1:length(unique_animals_in_group)
            animal = unique_animals_in_group{a};
            animal_indices = strcmp(animal_date_list(:, 3), animal) & group_indices;
            
            % Display all dates for this animal in the current group
            fprintf('For animal "%s" in group "%s", the dates are:\n', animal, group);
            disp(animal_date_list(animal_indices, 4));
            
            % Prompt user to input the ages
            age_input = input(sprintf('Enter age(s) for animal "%s" in group "%s" (e.g., 8:14 or 8 9 10): ', animal, group), 's');
            
            % Process user input
            if contains(age_input, ':')
                % If the user entered a range
                age_range = str2double(strsplit(age_input, ':'));
                age_list = age_range(1):age_range(2);
            else
                % Otherwise, consider the ages as separate
                age_list = str2double(strsplit(age_input));
            end
            
            % Assign ages to the dates for the animal in the current group
            age_index = 1; % To track the position in age_list
            for i = find(animal_indices)'
                if age_index <= length(age_list)
                    animal_date_list{i, 5} = sprintf('P%d', age_list(age_index));
                    age_index = age_index + 1;
                else
                    animal_date_list{i, 5} = 'N/A'; % Mark remaining ages as 'N/A' if not enough ages are provided
                end
            end
        end
    end

    % Display the updated list
    disp('List of animals with assigned ages:');
    disp(animal_date_list);
    
end
