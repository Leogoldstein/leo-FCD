function corr_groups_analysis(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)
    num_animals = length(selected_groups);
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;  % Numeric age representation
    
    % Data structure to store aggregated correlation values by age
    data_by_age = cell(numel(age_labels), 3);
    animal_names_by_age = cell(numel(age_labels), 1);
    
    % Iterate over each animal group
    for groupIdx = 1:num_animals
        current_animal_group = selected_groups(groupIdx).animal_group;
        current_ages_group = selected_groups(groupIdx).ages;
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
        [~, x_indices] = ismember(current_ages, age_values);
        
        all_max_corr_gcamp_gcamp = all_max_corr_gcamp_gcamp_groups{groupIdx};
        all_max_corr_gcamp_mtor = all_max_corr_gcamp_mtor_groups{groupIdx};
        all_max_corr_mtor_mtor = all_max_corr_mtor_mtor_groups{groupIdx};
        
        for sessionIdx = 1:length(current_ages_group)
            try
                ageIdx = x_indices(sessionIdx);
                data_added = false;
                
                if sessionIdx <= numel(all_max_corr_gcamp_gcamp) && ~isempty(all_max_corr_gcamp_gcamp{sessionIdx})
                    data_by_age{ageIdx, 1} = [data_by_age{ageIdx, 1}; all_max_corr_gcamp_gcamp{sessionIdx}(:)];
                    data_added = true;
                end
                if sessionIdx <= numel(all_max_corr_gcamp_mtor) && ~isempty(all_max_corr_gcamp_mtor{sessionIdx})
                    data_by_age{ageIdx, 2} = [data_by_age{ageIdx, 2}; all_max_corr_gcamp_mtor{sessionIdx}(:)];
                    data_added = true;
                end
                if sessionIdx <= numel(all_max_corr_mtor_mtor) && ~isempty(all_max_corr_mtor_mtor{sessionIdx})
                    data_by_age{ageIdx, 3} = [data_by_age{ageIdx, 3}; all_max_corr_mtor_mtor{sessionIdx}(:)];
                    data_added = true;
                end
                
                if data_added && ~any(strcmp(animal_names_by_age{ageIdx}, current_animal_group))
                    animal_names_by_age{ageIdx} = [animal_names_by_age{ageIdx}, {current_animal_group}];
                end
            catch ME
                fprintf('Error in session %d: %s\n', sessionIdx, ME.message);
            end
        end
    end
    
    % Plotting
    figure('Position', [100, 100, 1200, 600]);
    hold on;
    
    % Store handles for the legend
    h = zeros(1, 3);  % Initialize the handles for the three plot types (gcamp-gcamp, gcamp-mtor, mtor-mtor)
    plot_colors = {'g', 'c', 'b'};
    
    for ageIdx = 1:numel(age_labels)
        data_group = data_by_age(ageIdx, :);
        available_types = find(~cellfun(@isempty, data_group));
        num_types = numel(available_types);
        offsets = linspace(-0.25, 0.25, num_types); % Reset offsets for each new age
        
        % Flag to track if animal names have been plotted
        animal_names_plotted = false;
        
        for typeIdx = 1:num_types
            type = available_types(typeIdx);
            boxplot_data = data_by_age{ageIdx, type};
            if ~isempty(boxplot_data)
                boxplot_groups = repmat(ageIdx + offsets(typeIdx), length(boxplot_data), 1);
                boxplot(boxplot_data, boxplot_groups, 'Positions', ageIdx + offsets(typeIdx), 'Colors', plot_colors{type}, 'symbol', '');
                
                if h(type) == 0  % If the handle is not yet assigned
                    h(type) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{type}, 'MarkerFaceColor', plot_colors{type});
                end
                
                % Plot animal names only for the first typeIdx
                if ~animal_names_plotted && ~isempty(animal_names_by_age{ageIdx})
                    % Use the 25th percentile instead of min for positioning the text
                    percentile_25th = prctile(boxplot_data, 25);  % Calculate the 25th percentile
                    text(ageIdx + offsets(typeIdx), percentile_25th - 0.2, strjoin(animal_names_by_age{ageIdx}, '\n'), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8);
                    animal_names_plotted = true;  % Mark as plotted to avoid repetition
                end
            end
        end
    end
    
    % Configure plot
    xlabel('Age');
    ylabel('Max Correlation');
    title('Maximum Correlation by Age (Aggregated)');
    set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
    legend(h(h ~= 0), {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'}, 'Location', 'northwest');  % Use non-zero handles
    
    save_path = fullfile('D:', 'after_processing', 'Correlation analysis', ['Correlation_boxplots_' daytime '.png']);
    saveas(gcf, save_path);
    close(gcf);
end
