function [chosen_folder_processing_gcamp, chosen_folder_processing_blue] = create_base_folders(date_group_paths, current_gcamp_folders_names_group, current_blue_folders_names_group, daytime, user_choice1, user_choice2, current_animal_group)
    % Function to create or select subfolders for gcamp and blue channels independently

    chosen_folder_processing_gcamp = cell(length(current_gcamp_folders_names_group), 1);
    chosen_folder_processing_blue = cell(length(current_blue_folders_names_group), 1);

    all_specificSubfolders = cell(length(date_group_paths), 1);
    all_unique_subfolders = {};

    for k = 1:length(date_group_paths)
        folder_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing');
        folder_blue = fullfile(date_group_paths{k}, current_blue_folders_names_group{k}, 'after processing');

        % Gcamp subfolders
        subfolders_gcamp = dir(folder_gcamp);
        subfolders_gcamp = subfolders_gcamp([subfolders_gcamp.isdir]);
        subfolders_gcamp = subfolders_gcamp(~ismember({subfolders_gcamp.name}, {'.', '..'}));
        specificSubfolders_gcamp = subfolders_gcamp(~cellfun('isempty', regexp({subfolders_gcamp.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));

        % Blue subfolders (optional)
        specificSubfolders_blue = [];
        if ~isempty(current_blue_folders_names_group{k}) && ~isempty(current_blue_folders_names_group{k}(1))
            subfolders_blue = dir(folder_blue);
            subfolders_blue = subfolders_blue([subfolders_blue.isdir]);
            subfolders_blue = subfolders_blue(~ismember({subfolders_blue.name}, {'.', '..'}));
            specificSubfolders_blue = subfolders_blue(~cellfun('isempty', regexp({subfolders_blue.name}, '^\d{2}_\d{2}_\d{2}_\d{2}_\d{2}$', 'once')));
        end

        % Store subfolders
        all_specificSubfolders{k}.gcamp = specificSubfolders_gcamp;
        all_specificSubfolders{k}.blue = specificSubfolders_blue;

        % Append gcamp names only for the menu
        all_unique_subfolders = [all_unique_subfolders, {specificSubfolders_gcamp.name}];
    end

    % Remove duplicates
    unique_subfolders = unique(all_unique_subfolders);

    for k = 1:length(date_group_paths)
        gcamp_subfolders = all_specificSubfolders{k}.gcamp;
        blue_subfolders = all_specificSubfolders{k}.blue;

        % === Si aucun sous-dossier trouvé (gcamp), on en crée un ===
        if isempty(gcamp_subfolders)
            newSubfolderPath_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', daytime);
            mkdir(newSubfolderPath_gcamp);
            disp(['No subfolder found. Created new gcamp folder: ', newSubfolderPath_gcamp]);
            chosen_folder_processing_gcamp{k} = newSubfolderPath_gcamp;

            if ~isempty(current_blue_folders_names_group{k}) && ~isempty(current_blue_folders_names_group{k}(1))
                newSubfolderPath_blue = fullfile(date_group_paths{k}, current_blue_folders_names_group{k}, 'after processing', daytime);
                mkdir(newSubfolderPath_blue);
                disp(['No subfolder found. Created new blue folder: ', newSubfolderPath_blue]);
                chosen_folder_processing_blue{k} = newSubfolderPath_blue;
            else
                disp('Skipping blue folder creation due to missing name.');
                chosen_folder_processing_blue{k} = [];
            end
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

                % === Attribution pour gcamp ===
                match_gcamp = gcamp_subfolders(strcmp({gcamp_subfolders.name}, selected_subfolder_name));
                if ~isempty(match_gcamp)
                    chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', match_gcamp.name);
                    disp(['Selected gcamp subfolder: ', chosen_folder_processing_gcamp{k}]);
                end

                % === Attribution pour blue ===
                if ~isempty(blue_subfolders)
                    match_blue = blue_subfolders(strcmp({blue_subfolders.name}, selected_subfolder_name));
                    if ~isempty(match_blue)
                        chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, current_blue_folders_names_group{k}, 'after processing', match_blue.name);
                        disp(['Selected blue subfolder: ', chosen_folder_processing_blue{k}]);
                    else
                        chosen_folder_processing_blue{k} = [];
                    end
                end

            elseif strcmpi(user_choice2, '2') % création manuelle
                newFolderPath_gcamp = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', daytime);
                mkdir(newFolderPath_gcamp);
                disp(['Created new gcamp folder: ', newFolderPath_gcamp]);
                chosen_folder_processing_gcamp{k} = newFolderPath_gcamp;

                if ~isempty(current_blue_folders_names_group{k}) && ~isempty(current_blue_folders_names_group{k}(1))
                    newFolderPath_blue = fullfile(date_group_paths{k}, current_blue_folders_names_group{k}, 'after processing', daytime);
                    mkdir(newFolderPath_blue);
                    disp(['Created new blue folder: ', newFolderPath_blue]);
                    chosen_folder_processing_blue{k} = newFolderPath_blue;
                else
                    chosen_folder_processing_blue{k} = [];
                end
            end

        % === Choix automatique du plus récent ===
        elseif strcmpi(user_choice1, '1')
            % gcamp
            dates_gcamp = datetime({gcamp_subfolders.name}, 'InputFormat', 'yy_MM_dd_HH_mm', 'Format', 'yy_MM_dd_HH_mm');
            [~, idx_gcamp] = sort(dates_gcamp, 'descend');
            most_recent_gcamp = gcamp_subfolders(idx_gcamp(1));
            chosen_folder_processing_gcamp{k} = fullfile(date_group_paths{k}, current_gcamp_folders_names_group{k}, 'after processing', most_recent_gcamp.name);

            % blue (si dispo)
            if ~isempty(blue_subfolders)
                dates_blue = datetime({blue_subfolders.name}, 'InputFormat', 'yy_MM_dd_HH_mm', 'Format', 'yy_MM_dd_HH_mm');
                [~, idx_blue] = sort(dates_blue, 'descend');
                most_recent_blue = blue_subfolders(idx_blue(1));
                chosen_folder_processing_blue{k} = fullfile(date_group_paths{k}, current_blue_folders_names_group{k}, 'after processing', most_recent_blue.name);
            else
                chosen_folder_processing_blue{k} = [];
            end
        end
    end
end
