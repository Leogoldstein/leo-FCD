function animal_date_list = assign_age_to_animal(animal_date_list)
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
sauvegarde da,s