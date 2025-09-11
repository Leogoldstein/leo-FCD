function figs = FiringRateChange_around_SCEs(selected_groups)

    animal_types = unique(string({selected_groups.animal_type}));
    age_values = 7:15;
    age_labels = arrayfun(@(x) ['P', num2str(x)], age_values, 'UniformOutput', false);
    figs = struct();

    for typeIdx = 1:numel(animal_types)
        current_type = animal_types{typeIdx};
        type_groups_idx = find(arrayfun(@(x) strcmp(x.animal_type, current_type), selected_groups));
        if isempty(type_groups_idx), continue; end

        groups_subset = selected_groups(type_groups_idx);
        num_groups = length(groups_subset);
        delta_rate_by_age = cell(numel(age_values), 1);

        for groupIdx = 1:num_groups
            group = groups_subset(groupIdx);
            ages = cellfun(@(x) str2double(x(2:end)), group.ages);
            [~, age_indices] = ismember(ages, age_values);

            for pathIdx = 1:length(group.dates)
                ageIdx = age_indices(pathIdx);
                if ageIdx == 0, continue; end

                try
                    Raster = group.data.Raster_gcamp{pathIdx}; % matrice binaire (neurones x frames)
                    TRace = group.data.TRace_gcamp{pathIdx};   % frames des SCEs
                    sampling_rate = group.data.sampling_rate{pathIdx};

                    window_size = round(0.5 * sampling_rate);
                    num_neurons = size(Raster, 1);
                    num_frames = size(Raster, 2);
                    delta_rates = [];

                    for sce_frame = TRace
                        if sce_frame - window_size < 1 || sce_frame + window_size > num_frames
                            continue;
                        end

                        win_before = Raster(:, sce_frame - window_size : sce_frame - 1);
                        win_after  = Raster(:, sce_frame + 1 : sce_frame + window_size);

                        % Calcul du taux de décharge moyen par neurone (Hz)
                        rate_before = sum(win_before, 2) / (window_size / sampling_rate);
                        rate_after  = sum(win_after, 2) / (window_size / sampling_rate);

                        delta = mean(rate_after - rate_before, 'omitnan'); % Δ firing rate moyen
                        delta_rates(end+1) = delta;
                    end

                    if ~isempty(delta_rates)
                        delta_rate_by_age{ageIdx}(end+1) = mean(delta_rates, 'omitnan');
                    end
                catch ME
                    fprintf('Erreur (groupe %s, chemin %d) : %s\n', ...
                        group.animal_group, pathIdx, ME.message);
                end
            end
        end

        % -------- PLOT --------
        fig = figure('Name', ['Δ Fréquence de décharge - ', current_type], ...
                     'Position', [400, 300, 700, 400]);

        mean_rate = nan(size(age_values));
        sem_rate = nan(size(age_values));

        for ageIdx = 1:numel(age_values)
            values = delta_rate_by_age{ageIdx};
            if ~isempty(values)
                mean_rate(ageIdx) = mean(values, 'omitnan');
                sem_rate(ageIdx) = std(values, 'omitnan') / sqrt(numel(values));
            end
        end

        errorbar(age_values, mean_rate, sem_rate, '-o', ...
                 'LineWidth', 2, 'MarkerFaceColor', 'k', 'Color', 'g');

        xlabel('Âge postnatal (jours, P)');
        ylabel('Δ Fréquence de décharge (Hz)');
        title(['Variation de la fréquence de décharge après SCE - ', current_type]);
        xlim([6.5, 15.5]);
        ylim([-1, 2]); % à ajuster selon les données
        grid on;
        line([7, 15], [0 0], 'Color', [0.5 0.5 0.5], 'LineStyle', '--');

        figs.(current_type) = fig;
    end
end
