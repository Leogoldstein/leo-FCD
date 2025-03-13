function corr_groups_analysis(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)
    num_animals = length(selected_groups);
    animal_group = cell(num_animals, 1);
    colors = lines(num_animals); % Generate distinct colors

    % Data containers for aggregation
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    age_values = 7:15;  % Numeric age representation

    % Data structure to store correlation values by age
    data_by_age_gcamp_gcamp = cell(numel(age_labels), num_animals);
    data_by_age_gcamp_mtor = cell(numel(age_labels), num_animals);
    data_by_age_mtor_mtor = cell(numel(age_labels), num_animals);

    % Iterate over each unique animal-group combination
    for groupIdx = 1:num_animals
        current_animal_group = selected_groups(groupIdx).animal_group;
        animal_group{groupIdx} = current_animal_group;
        current_ages_group = selected_groups(groupIdx).ages;

        % Extract ages and map them to age indices
        current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group); % Remove 'P' and convert to number
        [~, x_indices] = ismember(current_ages, age_values);

        all_max_corr_gcamp_gcamp = all_max_corr_gcamp_gcamp_groups{groupIdx};
        all_max_corr_gcamp_mtor = all_max_corr_gcamp_mtor_groups{groupIdx};
        all_max_corr_mtor_mtor = all_max_corr_mtor_mtor_groups{groupIdx};

        % Iterate over sessions for the current animal
        for sessionIdx = 1:length(current_ages_group)
            try
                if sessionIdx <= numel(all_max_corr_gcamp_gcamp)
                    data_by_age_gcamp_gcamp{x_indices(sessionIdx), groupIdx} = all_max_corr_gcamp_gcamp{sessionIdx};
                end
                if sessionIdx <= numel(all_max_corr_gcamp_mtor)
                    data_by_age_gcamp_mtor{x_indices(sessionIdx), groupIdx} = all_max_corr_gcamp_mtor{sessionIdx};
                end
                if sessionIdx <= numel(all_max_corr_mtor_mtor)
                    data_by_age_mtor_mtor{x_indices(sessionIdx), groupIdx} = all_max_corr_mtor_mtor{sessionIdx};
                end
            catch ME
                fprintf('Error in group %s, session %d: %s\n', current_animal_group, sessionIdx, ME.message);
            end
        end
    end

    % Create a single figure for embedded boxplots
    figure('Position', [100, 100, 1200, 600]);
    hold on;

    % Store handles for the legend
    h = zeros(1, 3); % Handle for the three plot types

    % Iterate through ages to plot boxplots
    for ageIdx = 1:numel(age_labels)
        data_group = {data_by_age_gcamp_gcamp, data_by_age_gcamp_mtor, data_by_age_mtor_mtor};
        offsets = [-0.25, 0, 0.25]; % Offset for side-by-side boxplots
        % Custom colors for each type
        plot_colors = {'g', 'c', 'b'}; % Green for gcamp-gcamp, Cyan for gcamp-mtor, Blue for mtor-mtor

        for typeIdx = 1:3
            boxplot_data = [];
            boxplot_groups = [];

            for groupIdx = 1:num_animals
                if ~isempty(data_group{typeIdx}{ageIdx, groupIdx})
                    max_corr_values = data_group{typeIdx}{ageIdx, groupIdx};
                    
                    % Filter NaN values before adding to boxplots
                    max_corr_values = max_corr_values(~isnan(max_corr_values)); % Filter NaN
                    
                    if ~isempty(max_corr_values) % Check if there is data after filtering
                        boxplot_data = [boxplot_data; max_corr_values(:)];
                        boxplot_groups = [boxplot_groups; repmat(ageIdx + offsets(typeIdx), length(max_corr_values), 1)];
                    end
                else
                    % If no data, add a NaN value to guarantee plotting
                    boxplot_data = [boxplot_data; NaN];
                    boxplot_groups = [boxplot_groups; repmat(ageIdx + offsets(typeIdx), 1, 1)];
                end
            end

            % Check if there is data before plotting
            if ~isempty(boxplot_data)
                b = boxplot(boxplot_data, boxplot_groups, 'Positions', ageIdx + offsets(typeIdx), 'Colors', plot_colors{typeIdx});
                % Store the handle for the legend
                h(typeIdx) = plot(NaN, NaN, 's', 'MarkerEdgeColor', plot_colors{typeIdx}, 'MarkerFaceColor', plot_colors{typeIdx});
            end
        end
    end

    % Configure plot
    xlabel('Age');
    ylabel('Max Correlation');
    title('Maximum Correlation by Age and Group');
    set(gca, 'XTick', 1:numel(age_labels), 'XTickLabel', age_labels);
    
    % Add the legend manually
    legend(h, {'gcamp-gcamp', 'gcamp-mtor', 'mtor-mtor'}, 'Location', 'northwest');

    % Save figure
        save_path = fullfile('D:', 'after_processing', 'Correlation analysis', ['Correlation_boxplots_' daytime '.png']);
    saveas(gcf, save_path);
    close(gcf);
end
