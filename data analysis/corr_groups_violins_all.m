function corr_groups_violins_all(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)
    num_animals = length(selected_groups);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    
    data_by_age_and_type_and_animal = cell(numel(age_labels), 3, 3);
    used_animal_types = false(1, 3);
    animal_counts = zeros(numel(age_labels), 3);
    
    for groupIdx = 1:num_animals
        current_animal_type = selected_groups(groupIdx).animal_type;
        current_ages_group = selected_groups(groupIdx).ages;
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
        [~, x_indices] = ismember(current_ages, age_values);
        
        animalTypeIdx = find(strcmp(current_animal_type, {'jm', 'FCD', 'CTRL'}));
        unique_ages = unique(x_indices);
        for ageIdx = unique_ages'
            animal_counts(ageIdx, animalTypeIdx) = animal_counts(ageIdx, animalTypeIdx) + 1;
        end
        
        all_max_corr_gcamp_gcamp = all_max_corr_gcamp_gcamp_groups{groupIdx};
        all_max_corr_gcamp_mtor = all_max_corr_gcamp_mtor_groups{groupIdx};
        all_max_corr_mtor_mtor = all_max_corr_mtor_mtor_groups{groupIdx};
        
        use_animal_colors = all(cellfun(@isempty, all_max_corr_gcamp_mtor)) && all(cellfun(@isempty, all_max_corr_mtor_mtor));
        
        if use_animal_colors
            plot_colors = {'g', 'r', 'b'}; % red, magenta, yellow
        else
            plot_colors = {'g', 'c', 'b'}; % green, cyan, blue
        end
        
        for sessionIdx = 1:length(current_ages_group)
            try
                ageIdx = x_indices(sessionIdx);
                used_animal_types(animalTypeIdx) = true;
                
                if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
                    data_by_age_and_type_and_animal{ageIdx, 1, animalTypeIdx} = [... 
                        data_by_age_and_type_and_animal{ageIdx, 1, animalTypeIdx}; all_max_corr_gcamp_gcamp{sessionIdx}(:)];
                end
                
                if ~use_animal_colors
                    if sessionIdx <= numel(all_max_corr_gcamp_mtor) && ~isempty(all_max_corr_gcamp_mtor{sessionIdx})
                        data_by_age_and_type_and_animal{ageIdx, 2, animalTypeIdx} = [... 
                            data_by_age_and_type_and_animal{ageIdx, 2, animalTypeIdx}; all_max_corr_gcamp_mtor{sessionIdx}(:)];
                    end
                    
                    if sessionIdx <= numel(all_max_corr_mtor_mtor) && ~isempty(all_max_corr_mtor_mtor{sessionIdx})
                        data_by_age_and_type_and_animal{ageIdx, 3, animalTypeIdx} = [... 
                            data_by_age_and_type_and_animal{ageIdx, 3, animalTypeIdx}; all_max_corr_mtor_mtor{sessionIdx}(:)];
                    end
                end
                
            catch ME
                fprintf('Erreur dans la session %d: %s\n', sessionIdx, ME.message);
            end
        end
    end

    corrTypeLabels = {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'};
    animalTypeLabels = {'jm', 'FCD', 'CTRL'};
    
    for animalTypeIdx = 1:3
        for corrType = 1:3
            temp_data = [];
            temp_age = [];
    
            for ageIdx = 1:numel(age_labels)
                current_data = data_by_age_and_type_and_animal{ageIdx, corrType, animalTypeIdx};
                if ~isempty(current_data)
                    temp_data = [temp_data; current_data];
                    temp_age = [temp_age; repmat(age_labels(ageIdx), length(current_data), 1)];
                end
            end
    
            if ~isempty(temp_data)
                ordered_temp_age = categorical(temp_age, age_labels, 'Ordinal', true);
                [~, sortIdx] = sort(ordered_temp_age);
                sorted_data = temp_data(sortIdx);
                sorted_age = ordered_temp_age(sortIdx);
    
                age_with_n_labels = cell(1, numel(age_labels));
                for k = 1:numel(age_labels)
                    count = animal_counts(k, animalTypeIdx);
                    age_with_n_labels{k} = sprintf('%s (n=%d)', age_labels{k}, count);
                end
    
                figure
                violins = violinplot(sorted_data, sorted_age);
                ylabel('Pairwise correlation');
                title(sprintf('%s - %s', corrTypeLabels{corrType}, animalTypeLabels{animalTypeIdx}));
                xticklabels(age_with_n_labels);

                file_name = sprintf('Correlation_boxplots_%s_%s_%s.png', daytime, corrTypeLabels{corrType}, animalTypeLabels{animalTypeIdx});
                file_name = strrep(file_name, '-', '_');  % Facultatif : remplace les tirets pour éviter les soucis dans certains systèmes
                save_path = fullfile('D:', 'Imaging', 'Outputs', 'Correlation analysis', file_name);
                saveas(gcf, save_path);
            end
        end
    end



    

% BOXPLOTS

%     figure('Position', [100, 100, 1200, 600]);
%     hold on;
%     h = zeros(1, 3);
%     h_animal = zeros(1, 3);
%     animal_types = {'jm', 'FCD', 'CTRL'};
% 
%     for ageIdx = 1:numel(age_labels)
%         for corrTypeIdx = 1:3
%             for animalTypeIdx = 1:3
%                 boxplot_data = data_by_age_and_type_and_animal{ageIdx, corrTypeIdx, animalTypeIdx};
%                 if ~isempty(boxplot_data)
%                     offsets = linspace(-0.25, 0.25, 3);
%                     boxplot_groups = repmat(ageIdx + offsets(animalTypeIdx), length(boxplot_data), 1);
% 
%                     colorIdx = animalTypeIdx * use_animal_colors + corrTypeIdx * ~use_animal_colors;
%                     boxplot(boxplot_data, boxplot_groups, 'Positions', ageIdx + offsets(animalTypeIdx), 'Colors', plot_colors{colorIdx}, 'symbol', '');
% 
%                     if h(corrTypeIdx) == 0
%                         h(corrTypeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{colorIdx}, 'MarkerFaceColor', plot_colors{colorIdx});
%                     end
% 
%                     if used_animal_types(animalTypeIdx) && h_animal(animalTypeIdx) == 0
%                         h_animal(animalTypeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{colorIdx}, 'MarkerFaceColor', plot_colors{colorIdx});
%                     end
% 
%                     % Ajouter le nombre d'animaux sous les boxplots
%                     text(ageIdx + offsets(animalTypeIdx), min(boxplot_data) - 0.02, sprintf('n=%d', animal_counts(ageIdx, animalTypeIdx)), 'HorizontalAlignment', 'center', 'FontSize', 10);
%                 end
%             end
%         end
%     end
% 
%     xlabel('Age');
%     ylabel('Pairwise correlation');
%     title('Boxplots of Pairwise Correlation by Age and Animal Type');
%     set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
%     legend(h(h ~= 0), {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'}, 'Location', 'northwest');
% 
%     if any(used_animal_types)
%         legend(h_animal(used_animal_types), animal_types(used_animal_types), 'Location', 'northeast');
%     end
% 
%     save_path = fullfile('D:', 'Imaging', 'Outputs', ['Correlation_boxplots_' daytime '.png']);
%     saveas(gcf, save_path);
%     close(gcf);
% end