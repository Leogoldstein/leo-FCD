function chosen_folder_processing_gcamp = create_base_folders(date_group_paths, current_gcamp_folders_names_group, daytime, user_choice1, user_choice2, current_animal_group)
    % Function to create or select subfolders for gcamp channel only

    chosen_folder_processing_gcamp = cell(length(current_gcamp_folders_names_group), 1);

    all_specificSubfolders = cell(length(date_group_paths), 1);
    all_unique_subfolders = {};

    for k = 1:length(date_group_paths)
        folder_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing');

        % Gcamp subfolders
        subfolders_gcamp = dir(folder_gcamp);
        subfolders_gcamp = subfolders_gcamp([subfolders_gcamp.isdir]);
        subfolders_gcamp = subfolders_gcamp(~ismember({subfolders_gcamp.name}, {'.', '..'}));
        specificSubfolders_gcamp = subfolders_gcamp(~cellfun('isempty', regexp({subfolders_gcamp.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));

        % Store subfolders
        all_specificSubfolders{k}.gcamp = specificSubfolders_gcamp;

        % Append gcamp names only for the menu
        all_unique_subfolders = [all_unique_subfolders, {specificSubfolders_gcamp.name}];
    end

    % Remove duplicates
    unique_subfolders = unique(all_unique_subfolders);

    for k = 1:length(date_group_paths)
        gcamp_subfolders = all_specificSubfolders{k}.gcamp;

        % === Si aucun sous-dossier trouvé (gcamp), on en crée un ===
        if isempty(gcamp_subfolders)
            newSubfolderPath_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', daytime);
            mkdir(newSubfolderPath_gcamp);
            disp(['No subfolder found. Created new gcamp folder: ', newSubfolderPath_gcamp]);
            chosen_folder_processing_gcamp{k} = newSubfolderPath_gcamp;
            continue;
        end

        % === Si choix manuel d’un dossier ===
        if ~isempty(user_choice1) && strcmpi(user_choice1, '2')
            if ~isempty(user_choice2) && strcmpi(user_choice2, '1')
                % Affiche les options
                disp(['Available subfolders for ', current_animal_group, ':']);
                for j = 1:length(unique_subfolders)
                    disp(['Subfolder ', num2str(j), ': ', unique_subfolders{j}]);
                end
                selectedIndex = input('Enter the number corresponding to your choice: ');

                if selectedIndex < 1 || selectedIndex > length(unique_subfolders)
                    disp('Invalid choice. Exiting...');
                    return;
                end
                selected_subfolder_name = unique_subfolders{selectedIndex};

                % Attribution pour gcamp
                match_gcamp = gcamp_subfolders(strcmp({gcamp_subfolders.name}, selected_subfolder_name));
                if ~isempty(match_gcamp)
                    chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', match_gcamp.name);
                    disp(['Selected gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);
                end

            elseif strcmpi(user_choice2, '2') % création manuelle
                newFolderPath_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', daytime);
                mkdir(newFolderPath_gcamp);
                disp(['Created new gcamp folder: ', newFolderPath_gcamp]);
                chosen_folder_processing_gcamp{k} = newFolderPath_gcamp;
            end

        % === Choix automatique du plus récent ===
        elseif strcmpi(user_choice1, '1')
            dates_gcamp = datetime({gcamp_subfolders.name}, 'InputFormat', 'yy_MM_dd_HH_mm', 'Format', 'yy_MM_dd_HH_mm');
            [~, idx_gcamp] = sort(dates_gcamp, 'descend');
            most_recent_gcamp = gcamp_subfolders(idx_gcamp(1));
            chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', most_recent_gcamp.name);
        end
    end
end
