function [figs] = compare_groups_barplots(grouped_data_by_age)
    % Define animal groups to compare
    animal_types = fieldnames(grouped_data_by_age);
    num_groups = numel(animal_types);
    
    % Define the measures
    measures = {'NCells', 'ActivityFreq', 'NumSCEs', 'SCEFreq', 'AvgActiveSCE', 'SCEDuration', 'propSCEs'};
    measure_titles = {'NCells', 'Activity Frequency (per minute)', 'Number of SCEs', 'SCE Frequency', ...
                      'Number of Active Cells in SCEs (averaged)', 'SCE Duration (ms)', 'Percentage of Active Cells in SCEs (averaged)'};
    
    % Define the age labels
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};
    
    % Create the figure
    figs = figure('Name', 'Comparing Animal Groups by Age', 'Position', [100, 100, 1200, 800]);
    
    % Number of subplots
    num_measures = numel(measures);
    num_rows = ceil(num_measures / 2);
    num_columns = 2;
    
    % Loop over each measure to create subplots
    for measureIdx = 1:num_measures
        subplot(num_rows, num_columns, measureIdx); hold on;
        measure_name = measures{measureIdx};
        
        means = zeros(num_groups, numel(age_labels));
        stds = zeros(num_groups, numel(age_labels));
        
        for groupIdx = 1:num_groups
            data_by_age = grouped_data_by_age.(animal_types{groupIdx}).(measure_name);
            for ageIdx = 1:numel(age_labels)
                age_data = data_by_age(ageIdx, :);
                valid_data = age_data(~isnan(age_data));
                means(groupIdx, ageIdx) = mean(valid_data);
                stds(groupIdx, ageIdx) = std(valid_data);
            end
        end
        
        b = bar(means', 'grouped');
        
        for groupIdx = 1:num_groups
            x = b(groupIdx).XEndPoints;
            y = means(groupIdx, :);
            err = stds(groupIdx, :);
            errorbar(x, y, err, 'k.', 'LineWidth', 1);
        end
        
        xticks(1:numel(age_labels));
        xticklabels(age_labels);
        title(measure_titles{measureIdx});
        ylabel(measure_titles{measureIdx});
        xlabel('Age');
        legend(animal_types, 'Location', 'bestoutside');
        ylim([0, max(means(:) + stds(:)) * 1.2]);
    end
    
    % Adjust layout
    sgtitle('Comparison of Measures Between Animal Groups by Age');
    
    % Store the figure in the output structure
    figs = gcf;  % Store the current figure handle in the figs structure
end
