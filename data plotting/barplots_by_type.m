function [grouped_data_by_age, figs] = barplots_by_type(selected_groups)

    animal_types = {'jm', 'FCD', 'WT'};
    num_types = numel(animal_types);

    grouped_data_by_age = struct();
    figs = struct();

    for typeIdx = 1:num_types
        current_type = animal_types{typeIdx};
        type_groups_idx = find(arrayfun(@(x) strcmp(x.animal_type, current_type), selected_groups));

        if isempty(type_groups_idx)
            continue;
        end

        groups_subset = selected_groups(type_groups_idx);
        num_groups = numel(groups_subset);
        colors = lines(num_groups);

        % --- Définition des âges ---
        age_labels = {'P7','P8','P9','P10','P11','P12','P13','P14','P15'};
        age_values = 7:15;

        % === Conteneur des données ===
        data_by_age = struct( ...
            'NCells', nan(numel(age_labels), num_groups), ...
            'Z_position', nan(numel(age_labels), num_groups), ...
            'ActivityFreq', nan(numel(age_labels), num_groups), ...
            'PairwiseCorr', nan(numel(age_labels), num_groups), ...
            'NumSCEs', nan(numel(age_labels), num_groups), ...
            'SCE_Interv', nan(numel(age_labels), num_groups), ...
            'SCEDuration', nan(numel(age_labels), num_groups), ...
            'propSCEs', nan(numel(age_labels), num_groups), ...
            'Pburst', nan(numel(age_labels), num_groups), ...
            'Stability', nan(numel(age_labels), num_groups));  % <-- nouvelle mesure

        all_positions = [];

        % === Parcours des groupes ===
        for groupIdx = 1:num_groups
            current_dates_group = groups_subset(groupIdx).dates;
            current_ages_group = groups_subset(groupIdx).ages;
            current_env_group = groups_subset(groupIdx).env;
            data = groups_subset(groupIdx).data;

            current_ages = cellfun(@(x) str2double(x(2:end)), current_ages_group);
            [~, x_indices] = ismember(current_ages, age_values);

            for pathIdx = 1:length(current_dates_group)
                try
                    % --- Lecture XML pour Z ---
                    [~, ~, ~, position, ~, ~] = find_key_value(current_env_group{pathIdx});
                    if ~isempty(position) && ~isnan(position)
                        all_positions = [all_positions; position];
                    else
                        position = NaN;
                    end

                    % --- Extraction des données principales ---
                    DF = data.DF_gcamp{pathIdx};
                    Raster = data.Raster_gcamp{pathIdx};
                    Acttmp2 = data.Acttmp2_gcamp{pathIdx};
                    TRace = data.TRace_gcamp{pathIdx};
                    RasterRace = data.RasterRace_gcamp{pathIdx};
                    sces_distances = data.sces_distances_gcamp{pathIdx};
                    sampling_rate = data.sampling_rate{pathIdx};
                    corr_vals = data.max_corr_gcamp_gcamp{pathIdx};
                    Race = data.Race_gcamp{pathIdx};

                    % --- Vérification cohérence DF/Raster ---
                    if isempty(Raster) || isempty(DF)
                        warning('Empty Raster or DF for group %d path %d', groupIdx, pathIdx);
                        continue;
                    end
                    [n1, n2] = size(Raster);
                    DF = DF(1:min(size(DF,1),n1),1:min(size(DF,2),n2));
                    Raster = Raster(1:min(size(Raster,1),size(DF,1)),1:min(size(Raster,2),size(DF,2)));

                    [NCell, Nz] = size(Raster);

                    % === Calculs ===
                    % --- Sécuriser Acttmp2 ---
                    if iscell(Acttmp2)
                        freq = cellfun(@(x) numel(x)/Nz*sampling_rate*60, Acttmp2);
                    elseif isnumeric(Acttmp2)
                        if isempty(Acttmp2)
                            freq = nan(NCell,1);
                        elseif size(Acttmp2,2) == Nz
                            freq = sum(Acttmp2,2)/Nz*sampling_rate*60;
                        else
                            freq = nan(NCell,1);
                        end
                    else
                        freq = nan(NCell,1);
                    end
                    activity_frequency_minutes = mean(freq, 'omitnan');

                    % --- Corrélation moyenne ---
                    if ~isempty(corr_vals) && isnumeric(corr_vals)
                        r = corr_vals(:);
                        r = r(~isnan(r) & abs(r)<1);
                        if ~isempty(r)
                            z = 0.5*log((1+r)./(1-r));
                            mean_z = mean(z,'omitnan');
                            mean_pairwise_corr = (exp(2*mean_z)-1)/(exp(2*mean_z)+1);
                        else
                            mean_pairwise_corr = NaN;
                        end
                    else
                        mean_pairwise_corr = NaN;
                    end

                    % --- Nombre et intervalles SCEs ---
                    num_sces = numel(TRace);
                    mean_SCE_interv = NaN;
                    if num_sces > 1
                        mean_SCE_interv = mean(diff(TRace)/sampling_rate,'omitnan');
                    end

                    % --- Proportion de cellules actives par SCE ---
                    pourcentageActif = nan(length(TRace),1);
                    if ~isempty(TRace) && ~isempty(RasterRace)
                        for i = 1:length(TRace)
                            if TRace(i) <= size(RasterRace,2)
                                pourcentageActif(i) = 100*sum(RasterRace(:,TRace(i))==1)/NCell;
                            end
                        end
                    end
                    prop_active_cell_SCEs = mean(pourcentageActif,'omitnan');

                    % --- Durée moyenne des SCEs ---
                    frame_ms = 1000/sampling_rate;
                    if ~isempty(sces_distances) && size(sces_distances,2) >= 2
                        durations = sces_distances(:,2);
                    elseif ~isempty(sces_distances)
                        durations = sces_distances(:,1);
                    else
                        durations = [];
                    end
                    avg_duration_ms = mean(durations*frame_ms,'omitnan');

                    % --- Fraction d’événements en bursts ---
                    if ~isempty(Raster)
                        pop_counts = sum(Raster,1);
                        g = exp(-((-18:18).^2)/(2*3^2)); g=g/sum(g);
                        smooth_pop = conv(pop_counts,g,'same');
                        thr = mean(smooth_pop)+3*std(smooth_pop);
                        inBurstFrames = smooth_pop>thr;
                        totalEvents = sum(Raster(:));
                        if totalEvents > 0
                            P_burst = sum(Raster(:,inBurstFrames),'all') / totalEvents;
                        else
                            P_burst = NaN;
                        end
                    else
                        P_burst = NaN;
                    end

                    % --- Stabilité (Jaccard moyen entre SCEs successifs) ---
                    stability_mean = NaN;
                    if ~isempty(Race) && isnumeric(Race) && size(Race,2) > 1
                        nsce = size(Race,2);
                        jaccs = nan(1, nsce-1);
                        for j = 1:(nsce-1)
                            a = Race(:,j) > 0;
                            b = Race(:,j+1) > 0;
                            u = sum(a | b);
                            if u > 0
                                jaccs(j) = sum(a & b) / u;
                            end
                        end
                        stability_mean = mean(jaccs,'omitnan');
                    end

                    % === Stockage ===
                    data_by_age.NCells(x_indices(pathIdx),groupIdx)=NCell;
                    data_by_age.Z_position(x_indices(pathIdx),groupIdx)=position;
                    data_by_age.ActivityFreq(x_indices(pathIdx),groupIdx)=activity_frequency_minutes;
                    data_by_age.PairwiseCorr(x_indices(pathIdx),groupIdx)=mean_pairwise_corr;
                    data_by_age.NumSCEs(x_indices(pathIdx),groupIdx)=num_sces;
                    data_by_age.SCE_Interv(x_indices(pathIdx),groupIdx)=mean_SCE_interv;
                    data_by_age.SCEDuration(x_indices(pathIdx),groupIdx)=avg_duration_ms;
                    data_by_age.propSCEs(x_indices(pathIdx),groupIdx)=prop_active_cell_SCEs;
                    data_by_age.Pburst(x_indices(pathIdx),groupIdx)=P_burst;
                    data_by_age.Stability(x_indices(pathIdx),groupIdx)=stability_mean;

                catch ME
                    fprintf('Error group %d path %d: %s\n', groupIdx, pathIdx, ME.message);
                end
            end
        end

        % === Tracé ===
        measures = {'NCells','Z_position','ActivityFreq','PairwiseCorr',...
                    'NumSCEs','SCE_Interv','SCEDuration','propSCEs','Pburst','Stability'};
        measure_titles = {'NCells','Z Position (µm)','Activity Frequency (per minute)',...
                          'Mean Pairwise Correlation (Fisher z normalized)',...
                          'Number of SCEs','Inter-SCE Interval (s)','SCE Duration (ms)',...
                          'Percentage of Active Cells in SCEs (averaged)',...
                          'Fraction of events in bursts (P_burst)',...
                          'Stability (mean successive Jaccard)'};

        num_measures = numel(measures);
        num_rows = ceil(num_measures / 2);
        num_columns = 2;

        figure('Name', sprintf('Animal Type: %s', current_type), ...
               'Position', [100,100,1200,800]);

        % (1,1) NCells
        subplot(num_rows, num_columns, 1);
        means = nanmean(data_by_age.NCells,2);
        stds = nanstd(data_by_age.NCells,[],2);
        bar(means); hold on;
        errorbar(1:numel(means),means,stds,'k.');
        title('NCells'); xlabel('Age'); ylabel('Number of Cells');

        % (1,2) Histogramme Z
        subplot(num_rows, num_columns, 2);
        hold on;
        histogram(all_positions,20,'FaceColor',colors(1,:),'FaceAlpha',0.6);
        title(sprintf('Z Position Distribution - %s', current_type));
        xlabel('Z position (µm)'); ylabel('Count'); grid on;

        % Autres mesures
        for measureIdx = 3:num_measures
            subplot(num_rows, num_columns, measureIdx);
            measure_name = measures{measureIdx};
            bar_data = data_by_age.(measure_name);
            means = nanmean(bar_data,2);
            stds = nanstd(bar_data,[],2);
            bar(means); hold on;
            errorbar(1:numel(means),means,stds,'k.');
            title(measure_titles{measureIdx}); xlabel('Age');
        end

        grouped_data_by_age.(current_type) = data_by_age;
        figs.(current_type) = gcf;
    end
end
