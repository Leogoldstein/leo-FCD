function corr_groups_violins_inds(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)
    num_animals = length(selected_groups); % Nombre d'animaux
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    corrTypeLabels = {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'};
    animalTypeLabels = {'jm', 'FCD', 'CTRL'};
    
    for animalTypeIdx = 1:3
        for corrType = 1:3

            % Vérifie si ce type d'animal a des données valides pour ce type de corrélation
            has_data = false;
            for groupIdx = 1:num_animals
                if ~strcmp(selected_groups(groupIdx).animal_type, animalTypeLabels{animalTypeIdx})
                    continue;
                end
                switch corrType
                    case 1
                        corr_data = all_max_corr_gcamp_gcamp_groups{groupIdx};
                    case 2
                        corr_data = all_max_corr_gcamp_mtor_groups{groupIdx};
                    case 3
                        corr_data = all_max_corr_mtor_mtor_groups{groupIdx};
                end

                % Vérifie si au moins une session a des données non vides
                if any(cellfun(@(x) ~isempty(x), corr_data))
                    has_data = true;
                    break;
                end
            end

            if ~has_data
                continue; % Skip si aucune donnée à tracer pour ce type de corrélation/animal
            end

            % Création de la figure uniquement si des données existent
            figure('Name', sprintf('%s - %s', corrTypeLabels{corrType}, animalTypeLabels{animalTypeIdx}), 'Position', [100, 100, 1600, 800]);
            subplot_idx = 1;

            for groupIdx = 1:num_animals
                current_animal_type = selected_groups(groupIdx).animal_type;
                if ~strcmp(current_animal_type, animalTypeLabels{animalTypeIdx})
                    continue;
                end

                current_ages_group = selected_groups(groupIdx).ages;
                current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
                [~, x_indices] = ismember(current_ages, age_values);

                switch corrType
                    case 1
                        all_max_corr = all_max_corr_gcamp_gcamp_groups{groupIdx};
                    case 2
                        all_max_corr = all_max_corr_gcamp_mtor_groups{groupIdx};
                    case 3
                        all_max_corr = all_max_corr_mtor_mtor_groups{groupIdx};
                end

                animal_data = [];
                animal_age = [];

                for sessionIdx = 1:length(current_ages_group)
                    ageIdx = x_indices(sessionIdx);
                    if sessionIdx <= numel(all_max_corr) && ~isempty(all_max_corr{sessionIdx})
                        current_corrs = all_max_corr{sessionIdx}(:);
                        animal_data = [animal_data; current_corrs];
                        animal_age = [animal_age; repmat(age_labels(ageIdx), length(current_corrs), 1)];
                    end
                end

                if ~isempty(animal_data)
                    subplot(ceil(num_animals / 3), 3, subplot_idx); % Organise les subplots (ajuste si nécessaire)
                    subplot_idx = subplot_idx + 1;

                    ordered_temp_age = categorical(animal_age, age_labels, 'Ordinal', true);
                    [~, sortIdx] = sort(ordered_temp_age);
                    sorted_data = animal_data(sortIdx);
                    sorted_age = ordered_temp_age(sortIdx);

                    violinplot(sorted_data, sorted_age);
                    
                    % Utilise le nom du groupe d'animal plutôt que "Animal 1", "Animal 2", etc.
                    title(sprintf('%s', selected_groups(groupIdx).animal_group));
                    ylabel('Corrélation');
                    xticklabels(age_labels);
                end
            end

            sgtitle(sprintf('%s - %s', corrTypeLabels{corrType}, animalTypeLabels{animalTypeIdx}));

            file_name = sprintf('Subplot_Corr_%s_%s.png', corrTypeLabels{corrType}, animalTypeLabels{animalTypeIdx});
            file_name = strrep(file_name, '-', '_');
            save_path = fullfile('D:', 'Imaging', 'Outputs', 'Correlation analysis', file_name);
            saveas(gcf, save_path);
        end
    end
end
