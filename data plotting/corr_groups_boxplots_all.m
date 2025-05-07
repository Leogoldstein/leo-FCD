function figs = corr_groups_boxplots_all(selected_groups)
    num_animals = length(selected_groups);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    animal_types = {'jm', 'FCD', 'CTRL'};
    figs = struct();

    for animalTypeIdx = 1:numel(animal_types)
        current_type = animal_types{animalTypeIdx};

        data_by_age_and_corr = cell(numel(age_labels), 3);  % 3 correlation types
        animal_counts = zeros(numel(age_labels), 1);
        animal_groups = {};  % Pour stocker les groupes d'animaux uniques

        for groupIdx = 1:num_animals
            if ~strcmp(selected_groups(groupIdx).animal_type, current_type)
                continue;
            end

            current_ages_group = selected_groups(groupIdx).ages;
            current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
            [~, x_indices] = ismember(current_ages, age_values);

            all_max_corr_gcamp_gcamp = selected_groups(groupIdx).gcamp_data.max_corr_gcamp_gcamp;
            all_max_corr_gcamp_mtor = selected_groups(groupIdx).gcamp_data.max_corr_gcamp_mtor;
            all_max_corr_mtor_mtor = selected_groups(groupIdx).gcamp_data.max_corr_mtor_mtor;

            use_animal_colors = all(cellfun(@isempty, all_max_corr_gcamp_mtor)) && all(cellfun(@isempty, all_max_corr_mtor_mtor));

            % Choisir les couleurs en fonction de use_animal_colors
            if use_animal_colors
                plot_colors = {'r', 'm', 'y'};  % Rouge, Magenta, Jaune
            else
                plot_colors = {'g', 'c', 'b'};  % Vert, Cyan, Bleu
            end

            % Ajouter le groupe d'animaux à la liste
            current_group = string(selected_groups(groupIdx).animal_group);
            if ~ismember(current_group, string(animal_groups))
                animal_groups{end+1} = char(current_group);  % On stocke comme texte standard
            end

            for sessionIdx = 1:length(current_ages_group)
                try
                    ageIdx = x_indices(sessionIdx);
                    animal_counts(ageIdx) = animal_counts(ageIdx) + 1;

                    if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
                        data_by_age_and_corr{ageIdx, 1} = [data_by_age_and_corr{ageIdx, 1}; all_max_corr_gcamp_gcamp{sessionIdx}(:)];
                    end

                    if ~use_animal_colors
                        if sessionIdx <= numel(all_max_corr_gcamp_mtor) && ~isempty(all_max_corr_gcamp_mtor{sessionIdx})
                            data_by_age_and_corr{ageIdx, 2} = [data_by_age_and_corr{ageIdx, 2}; all_max_corr_gcamp_mtor{sessionIdx}(:)];
                        end

                        if sessionIdx <= numel(all_max_corr_mtor_mtor) && ~isempty(all_max_corr_mtor_mtor{sessionIdx})
                            data_by_age_and_corr{ageIdx, 3} = [data_by_age_and_corr{ageIdx, 3}; all_max_corr_mtor_mtor{sessionIdx}(:)];
                        end
                    end
                catch ME
                    fprintf('Erreur dans la session %d: %s\n', sessionIdx, ME.message);
                end
            end
        end

        % Ne crée une figure que s'il y a des données
        if all(cellfun(@isempty, data_by_age_and_corr(:)))
            continue;
        end

        figure('Name', sprintf('Correlations - %s', current_type), 'Position', [100, 100, 1200, 600]);
        hold on;
        legends_corr = {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'};
        h_corr = zeros(1, 3);
        h_animal_groups = zeros(1, numel(animal_groups));  % Pour les handles des groupes d'animaux

        for ageIdx = 1:numel(age_labels)
            for corrTypeIdx = 1:3
                corr_data = data_by_age_and_corr{ageIdx, corrTypeIdx};
                if ~isempty(corr_data)
                    offset = (corrTypeIdx - 2) * 0.2;  % Positions décalées
                    boxplot(corr_data, ...
                            'positions', ageIdx + offset, ...
                            'colors', plot_colors{corrTypeIdx}, ...
                            'symbol', '', ...
                            'Widths', 0.15);

                    if h_corr(corrTypeIdx) == 0
                        h_corr(corrTypeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{corrTypeIdx}, ...
                                                   'MarkerFaceColor', plot_colors{corrTypeIdx});
                    end

                    text(ageIdx + offset, min(corr_data) - 0.02, ...
                         sprintf('n=%d', animal_counts(ageIdx)), ...
                         'HorizontalAlignment', 'center', 'FontSize', 9);
                end
            end
        end

        % Ajouter la légende pour les types de corrélation
        legend_corr = h_corr(h_corr ~= 0);
        legend_labels = legends_corr(h_corr ~= 0);

        % Ajouter une légende séparée pour les noms des groupes d'animaux
        for i = 1:numel(animal_groups)
            h_animal_groups(i) = plot(NaN, NaN, 'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k'); % On met une couleur neutre (noir)
        end

        % Légende combinée
        legend_combined = [legend_corr, h_animal_groups];
        legend_labels_combined = [legend_labels, animal_groups];

        % Placer la légende dans le coin supérieur droit
        legend(legend_combined, legend_labels_combined, 'Location', 'northeast');

        xlabel('Age');
        ylabel('Pairwise correlation');
        title(sprintf('Boxplots of Pairwise Correlation - %s', current_type));
        set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
        
        figs.(current_type) = gcf;
        %close(gcf)
    end
end
