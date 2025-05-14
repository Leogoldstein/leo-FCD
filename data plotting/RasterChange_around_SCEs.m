function figs = RasterChange_around_SCEs(selected_groups)

    animal_types = unique(string({selected_groups.animal_type}));
    disp("Nombre de types d'animaux :")

    age_labels = {'P7', 'P8', 'P9', 'P10', 'P11', 'P12', 'P13', 'P14', 'P15'}; 
    age_values = 7:15;
    
    figs = struct();

    for typeIdx = 1:numel(animal_types)
        current_type = animal_types{typeIdx};

        type_groups_idx = find(arrayfun(@(x) strcmp(x.animal_type, current_type), selected_groups));
        if isempty(type_groups_idx)
            disp(['Aucun groupe trouvé pour le type ', current_type]);
            continue;
        end

        groups_subset = selected_groups(type_groups_idx);
        num_groups = length(groups_subset);
        colors = lines(num_groups);
        traces_by_age_group = cell(numel(age_values), num_groups);

        for groupIdx = 1:num_groups
            group = groups_subset(groupIdx);

            ages = cellfun(@(x) str2double(x(2:end)), group.ages);
            [~, age_indices] = ismember(ages, age_values);

            if any(age_indices == 0)
                continue;
            end

            for pathIdx = 1:length(group.dates)
                try
                    Raster = group.gcamp_data.Raster{pathIdx};
                    TRace = group.gcamp_data.TRace{pathIdx};
                    sampling_rate = group.gcamp_data.sampling_rate{pathIdx};

                    window_size = round(0.5 * sampling_rate);
                    num_frames = size(Raster, 2);
                    aligned_traces = [];

                    for sce_frame = TRace
                        if sce_frame - window_size < 1 || sce_frame + window_size > num_frames
                            disp(['    -> SCE ignoré (hors limites) dans chemin ', num2str(pathIdx)]);
                            continue;
                        end
                        segment = Raster(:, sce_frame - window_size : sce_frame + window_size);
                        avg_trace = sum(segment, 1) / size(Raster, 1); % Calcul de la proportion de neurones actifs

                        aligned_traces(end+1, :) = avg_trace;

                    end

                    if ~isempty(aligned_traces)
                        ageIdx = age_indices(pathIdx);
                        traces_by_age_group{ageIdx, groupIdx} = [traces_by_age_group{ageIdx, groupIdx}; aligned_traces];
                    else
                        disp(['    -> Aucun SCE aligné pour chemin ', num2str(pathIdx)]);
                    end
                catch ME
                    fprintf('    -> Erreur (groupe %s, chemin %d) : %s\n', group.animal_group, pathIdx, ME.message);
                end
            end
        end

        % ---------------- PLOT -----------------
        fig = figure('Name', sprintf('Raster autour des SCEs - %s', current_type), ...
                     'Position', [100, 100, 800, 800]); % Taille de la figure ajustée
        
        first_group_ages = 7:11;  % P7 à P11
        second_group_ages = 12:15; % P12 à P15
        
        for ageIdx = 1:numel(age_values)
            if ismember(age_values(ageIdx), first_group_ages)
                row = 1;
                col = age_values(ageIdx) - 6; % Colonnes 1 à 5
            elseif ismember(age_values(ageIdx), second_group_ages)
                row = 2;
                col = age_values(ageIdx) - 11 + 5; % Colonnes 6 à 9
            else
                continue;
            end

            subplot(2, 5, col);
            hold on;

            all_traces_for_age = [];
            animal_ids = [];

            for groupIdx = 1:num_groups
                traces = traces_by_age_group{ageIdx, groupIdx};
                if isempty(traces)
                    continue;
                end
                all_traces_for_age = [all_traces_for_age; traces];
                animal_ids = [animal_ids, groupIdx];  % ou utiliser des IDs uniques si disponibles
            end

            num_animals = numel(unique(animal_ids)); % nombre d’animaux pour cet âge

            if ~isempty(all_traces_for_age)
                mean_trace = mean(all_traces_for_age, 1, 'omitnan');
                std_trace = std(all_traces_for_age, 0, 1, 'omitnan');
                
                x = linspace(-0.5, 0.5, size(mean_trace, 2));
                plot(x, mean_trace, 'k', 'LineWidth', 2);
                fill([x, fliplr(x)], [mean_trace + std_trace, fliplr(mean_trace - std_trace)], ...
                    'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

                % [maxY, maxIdx] = max(mean_trace);
                % maxX = x(maxIdx);
                % plot([-0.5, maxX], [maxY, maxY], 'k--', 'LineWidth', 1); % Ligne horizontale du maximum
            end

            %ylim([0, 1.5]);
            plot([0, 0], ylim, 'k--', 'LineWidth', 1); % Ligne verticale à t=0

            title(['Âge ', age_labels{ageIdx}]);
            xlabel('Temps (s)');
            ylabel('Proportion of active neurons');
            xlim([-0.5, 0.5]);

            % Afficher le nombre d'animaux en haut à gauche
            text(-0.45, 1.4, ['n = ', num2str(num_animals)], ...
                 'FontSize', 10, 'FontWeight', 'normal', 'HorizontalAlignment', 'left');

            hold off;
        end

        figs.(current_type) = fig;
    end
end
