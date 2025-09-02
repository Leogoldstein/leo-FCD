function figs = corr_groups_boxplots_all(selected_groups)
    num_animals = length(selected_groups);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    animal_types = {'jm', 'FCD', 'CTRL'};
    figs = struct();

    % Stocker les données gcamp-gcamp par type et par âge
    data_all_types = cell(numel(animal_types), numel(age_labels));
    animal_counts_all = zeros(numel(animal_types), numel(age_labels));

    for animalTypeIdx = 1:numel(animal_types)
        current_type = animal_types{animalTypeIdx};

        for groupIdx = 1:num_animals
            if ~strcmp(selected_groups(groupIdx).animal_type, current_type)
                continue;
            end

            data = selected_groups(groupIdx).data;
            current_ages_group = selected_groups(groupIdx).ages;
            current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
            [~, x_indices] = ismember(current_ages, age_values);

            all_max_corr_gcamp_gcamp = data.max_corr_gcamp_gcamp;

            for sessionIdx = 1:length(current_ages_group)
                try
                    ageIdx = x_indices(sessionIdx);
                    if isempty(ageIdx) || ageIdx == 0
                        continue;
                    end
                    animal_counts_all(animalTypeIdx, ageIdx) = ...
                        animal_counts_all(animalTypeIdx, ageIdx) + 1;

                    if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ...
                       ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
                        data_all_types{animalTypeIdx, ageIdx} = ...
                            [data_all_types{animalTypeIdx, ageIdx}; all_max_corr_gcamp_gcamp{sessionIdx}(:)];
                    end
                catch ME
                    fprintf('Erreur dans la session %d: %s\n', sessionIdx, ME.message);
                end
            end
        end

        % Créer figure individuelle par type
        if any(cellfun(@(x) ~isempty(x), data_all_types(animalTypeIdx, :)))
            figure('Name', sprintf('Correlations - %s', current_type), 'Position', [100, 100, 1200, 600]);
            hold on;
            colors = {'r', 'm', 'y'}; % Couleurs pour gcamp-gcamp
            for ageIdx = 1:numel(age_labels)
                corr_data = data_all_types{animalTypeIdx, ageIdx};
                if ~isempty(corr_data)
                    boxplot(corr_data, 'positions', ageIdx, 'colors', colors{1}, ...
                        'symbol', '', 'Widths', 0.15);
                    text(ageIdx, min(corr_data) - 0.02, sprintf('n=%d', animal_counts_all(animalTypeIdx, ageIdx)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 9);
                end
            end
            xlabel('Age');
            ylabel('Pairwise correlation');
            title(sprintf('Boxplots of Pairwise Correlation - %s', current_type));
            set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
            figs.(current_type) = gcf;
        end
    end

    % --- Figure combinée ---
    % Vérifier les âges avec au moins un type ayant des données
    ages_with_data = find(any(~cellfun(@isempty, data_all_types), 1));
    if ~isempty(ages_with_data)
        figure('Name', 'Combined gcamp-gcamp', 'Position', [100, 100, 1400, 600]);
        hold on;
        type_colors = {'r', 'g', 'b'};
        width_offset = 0.2;  % Décalage pour chaque type
        for ageIdx = ages_with_data
            for animalTypeIdx = 1:numel(animal_types)
                corr_data = data_all_types{animalTypeIdx, ageIdx};
                if ~isempty(corr_data)
                    offset = (animalTypeIdx - 2) * width_offset;  % -0.2, 0, +0.2
                    boxplot(corr_data, 'positions', ageIdx + offset, ...
                        'colors', type_colors{animalTypeIdx}, 'symbol', '', 'Widths', 0.15);
                    text(ageIdx + offset, min(corr_data) - 0.02, ...
                        sprintf('n=%d', animal_counts_all(animalTypeIdx, ageIdx)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 9);
                end
            end
        end
        xlabel('Age');
        ylabel('Pairwise correlation');
        title('Combined gcamp-gcamp Correlations');
        set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
        % Légende
        h = zeros(1, numel(animal_types));
        for i = 1:numel(animal_types)
            h(i) = plot(NaN, NaN, 's', 'MarkerEdgeColor', type_colors{i}, 'MarkerFaceColor', type_colors{i});
        end
        legend(h, animal_types, 'Location', 'northeast');
        figs.Combined = gcf;
    end
end
