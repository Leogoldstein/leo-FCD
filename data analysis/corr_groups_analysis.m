function corr_groups_analysis(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)
    num_animals = length(selected_groups);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;
    
    data_by_age_and_type_and_animal = cell(numel(age_labels), 3, 3); % cell to store data for each age, type, and animal group
    
    % Initialize a variable to track which animal types are used in the plot
    used_animal_types = false(1, 3); % [jm, FCD, CTRL]
    
    for groupIdx = 1:num_animals
        current_animal_type = selected_groups(groupIdx).animal_type;
        current_ages_group = selected_groups(groupIdx).ages;
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
        [~, x_indices] = ismember(current_ages, age_values);
        
        all_max_corr_gcamp_gcamp = all_max_corr_gcamp_gcamp_groups{groupIdx};
        all_max_corr_gcamp_mtor = all_max_corr_gcamp_mtor_groups{groupIdx};
        all_max_corr_mtor_mtor = all_max_corr_mtor_mtor_groups{groupIdx};
        
        use_animal_colors = all(cellfun(@isempty, all_max_corr_gcamp_mtor)) && all(cellfun(@isempty, all_max_corr_mtor_mtor));
        
        if use_animal_colors
            plot_colors = {'r', 'm', 'y'}; % red, magenta, yellow
        else
            plot_colors = {'g', 'c', 'b'}; % green, cyan, blue
        end
        
        for sessionIdx = 1:length(current_ages_group)
            try
                ageIdx = x_indices(sessionIdx); % Get the age index
                animalTypeIdx = find(strcmp(current_animal_type, {'jm', 'FCD', 'CTRL'})); % Find the animal type index
                
                % Mark this animal type as used
                used_animal_types(animalTypeIdx) = true;
                
                % Aggregate data for gcamp-gcamp
                if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
                    data_by_age_and_type_and_animal{ageIdx, 1, animalTypeIdx} = [... 
                        data_by_age_and_type_and_animal{ageIdx, 1, animalTypeIdx}; all_max_corr_gcamp_gcamp{sessionIdx}(:)];
                end
                
                % Aggregate data for gcamp-mtor (if available)
                if ~use_animal_colors
                    if sessionIdx <= numel(all_max_corr_gcamp_mtor) && ~isempty(all_max_corr_gcamp_mtor{sessionIdx})
                        data_by_age_and_type_and_animal{ageIdx, 2, animalTypeIdx} = [... 
                            data_by_age_and_type_and_animal{ageIdx, 2, animalTypeIdx}; all_max_corr_gcamp_mtor{sessionIdx}(:)];
                    end
                    
                    % Aggregate data for mtor-mtor (if available)
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
    
    assignin('base', 'data_by_age_and_type_and_animal', data_by_age_and_type_and_animal);

    figure('Position', [100, 100, 1200, 600]);
    hold on;
    h = zeros(1, 3);
    h_animal = zeros(1, 3);
    animal_types = {'jm', 'FCD', 'CTRL'};
    
    for ageIdx = 1:numel(age_labels)
        for corrTypeIdx = 1:3
            for animalTypeIdx = 1:3
                boxplot_data = data_by_age_and_type_and_animal{ageIdx, corrTypeIdx, animalTypeIdx};
                if ~isempty(boxplot_data)
                    offsets = linspace(-0.25, 0.25, 3);
                    boxplot_groups = repmat(ageIdx + offsets(animalTypeIdx), length(boxplot_data), 1);
                    
                    colorIdx = animalTypeIdx * use_animal_colors + corrTypeIdx * ~use_animal_colors;
                    boxplot(boxplot_data, boxplot_groups, 'Positions', ageIdx + offsets(animalTypeIdx), 'Colors', plot_colors{colorIdx}, 'symbol', '');
                    
                    if h(corrTypeIdx) == 0
                        h(corrTypeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{colorIdx}, 'MarkerFaceColor', plot_colors{colorIdx});
                    end
                    
                    % Only create h_animal handle if this animal type is being used
                    if used_animal_types(animalTypeIdx) && h_animal(animalTypeIdx) == 0
                        h_animal(animalTypeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{colorIdx}, 'MarkerFaceColor', plot_colors{colorIdx});
                    end
                end
            end
        end
    end
    
    xlabel('Age');
    ylabel('Max Correlation');
    title('Maximum Correlation by Age, Animal Type, and Correlation Type');
    set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
    legend(h(h ~= 0), {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'}, 'Location', 'northwest');
    
    % Only include animal type legend if the animal types are used in the plot
    if any(used_animal_types)
        legend(h_animal(used_animal_types), animal_types(used_animal_types), 'Location', 'northeast');
    end
    
    save_path = fullfile('D:', 'after_processing', 'Correlation analysis', ['Correlation_boxplots_' daytime '.png']);
    saveas(gcf, save_path);
    close(gcf);
end
