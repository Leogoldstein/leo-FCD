function [figs] = compare_groups_barplots(grouped_data_by_age)
    % Compare des groupes animaux par âge sur plusieurs mesures
    % (incluant Inter-SCE Interval à la place de la SCE Frequency)

    % --- Définir les groupes ---
    animal_types = fieldnames(grouped_data_by_age);
    num_groups = numel(animal_types);

    % --- Définir l'ordre des mesures ---
    measures = {'NCells', 'ActivityFreq', 'PairwiseCorr', ...
                'NumSCEs', 'SCE_Interv', 'SCEDuration', ...
                'propSCEs', 'Pburst'};

    measure_titles = {'NCells', ...
                      'Activity Frequency (per minute)', ...
                      'Mean Pairwise Correlation (Fisher z normalized)', ...
                      'Number of SCEs', ...
                      'Inter-SCE Interval (s)', ...
                      'SCE Duration (ms)', ...
                      'Percentage of Active Cells in SCEs (averaged)', ...
                      'Fraction of events in bursts (P_burst)'};

    % --- Âges ---
    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'};

    % --- Création figure principale ---
    figs = figure('Name', 'Comparing Animal Groups by Age', ...
                  'Position', [100, 100, 1200, 800]);

    num_measures = numel(measures);
    num_rows = ceil(num_measures / 2);
    num_columns = 2;

    % === Boucle sur chaque mesure ===
    for measureIdx = 1:num_measures
        subplot(num_rows, num_columns, measureIdx); hold on;
        measure_name = measures{measureIdx};

        means = zeros(num_groups, numel(age_labels));
        stds = zeros(num_groups, numel(age_labels));

        for groupIdx = 1:num_groups
            data_by_age = grouped_data_by_age.(animal_types{groupIdx}).(measure_name);

            % Normalisation Fisher z pour PairwiseCorr
            if strcmp(measure_name, 'PairwiseCorr')
                data_by_age_z = data_by_age;
                data_by_age_z(abs(data_by_age_z) >= 1) = NaN;
                z_vals = 0.5 * log((1 + data_by_age_z) ./ (1 - data_by_age_z));
            else
                z_vals = data_by_age;
            end

            for ageIdx = 1:numel(age_labels)
                age_data = z_vals(ageIdx, :);
                valid_data = age_data(~isnan(age_data));

                if isempty(valid_data)
                    means(groupIdx, ageIdx) = NaN;
                    stds(groupIdx, ageIdx) = NaN;
                else
                    if strcmp(measure_name, 'PairwiseCorr')
                        mean_z = mean(valid_data);
                        means(groupIdx, ageIdx) = (exp(2*mean_z) - 1) / (exp(2*mean_z) + 1);
                        stds(groupIdx, ageIdx) = std(valid_data);
                    else
                        means(groupIdx, ageIdx) = mean(valid_data);
                        stds(groupIdx, ageIdx) = std(valid_data);
                    end
                end
            end
        end

        % --- Barplot ---
        b = bar(means', 'grouped');

        % --- Barres d'erreur ---
        for groupIdx = 1:num_groups
            x = b(groupIdx).XEndPoints;
            y = means(groupIdx, :);
            err = stds(groupIdx, :);
            errorbar(x, y, err, 'k.', 'LineWidth', 1);
        end

        % --- Mise en forme ---
        xticks(1:numel(age_labels));
        xticklabels(age_labels);
        title(measure_titles{measureIdx});
        ylabel(measure_titles{measureIdx});
        xlabel('Age');
        legend(animal_types, 'Location', 'bestoutside');

        ylim([0, max(means(:) + stds(:), [], 'omitnan') * 1.2]);
    end

    sgtitle('Comparison of Measures Between Animal Groups by Age');
    figs = gcf;
end
