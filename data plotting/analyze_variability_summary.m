function figs = analyze_variability_summary(selected_groups)
    animal_types = {'jm','FCD','CTRL'};
    figs = struct();
    
    % --- Couleurs fixes pour les âges P7-P15 ---
    age_labels = 7:15;
    n_ages = numel(age_labels);
    age_cmap = parula(n_ages); % ou lines(n_ages)
    age_colors = containers.Map(num2cell(age_labels), num2cell(age_cmap,2));
    
    % --- Couleurs pour les états ---
    state_colors = [0.8 0.2 0.2; 0.2 0.8 0.2; 0.2 0.2 0.8; 0.8 0.6 0.2]; % rouge, vert, bleu, ocre
    
    for aIdx = 1:numel(animal_types)
        current_type = animal_types{aIdx};
        
        % --- Préparer table pour toutes les sessions de ce type ---
        results_table = table([],[],[],[],[],[],[],[], 'VariableNames', ...
            {'session_age','animal_group','variability','cross_mean','activity_rate', ...
             'sce_frequency_hz','avg_cells_sces','avg_percent_cells_sces'});
    
        for gIdx = 1:length(selected_groups)
            grp = selected_groups(gIdx);
            if ~strcmp(grp.animal_type, current_type)
                continue
            end
            
            % --- Charger données corr et SCE ---
            data_corr = load_or_process_corr_data(grp.gcamp_output_folders, grp.data);
            grp.data = data_corr;
            data_sce = load_or_process_sce_data(grp.animal_group, grp.dates, grp.gcamp_output_folders, grp.data);
            grp.data = data_sce;
    
            ages_num = cellfun(@(x) str2double(x(2:end)), grp.ages);
    
            % --- Boucle sur les sessions ---
            for sIdx = 1:length(grp.dates)
                Raster_gcamp = grp.data.Raster_gcamp{sIdx};
                cross_corr_gcamp  = grp.data.max_corr_gcamp_gcamp{sIdx};
                Race_gcamp = grp.data.Race_gcamp{sIdx};
                RasterRace_gcamp = grp.data.RasterRace_gcamp{sIdx};
                sampling_rate = grp.data.sampling_rate{sIdx};
                TRace_gcamp = grp.data.TRace_gcamp{sIdx};
    
                if isempty(Raster_gcamp) || size(Raster_gcamp,2)<10
                    continue
                end
    
                % --- Mesure de variabilité de l'activité ---
                aggRaster = sum(Raster_gcamp,1);         % activité globale par temps
                activity_mean = mean(aggRaster);
                activity_std = std(aggRaster);
                variability = activity_std / activity_mean;  % coefficient de variation
    
                % --- Métriques de coordination ---
                cross_mean = mean(cross_corr_gcamp(triu(true(size(cross_corr_gcamp)),1)),'omitnan');
                activity_rate = mean(Raster_gcamp(:));
    
                % --- Métriques SCE ---
                nb_sces = numel(TRace_gcamp);
                nb_seconds = size(Raster_gcamp,2) / sampling_rate;
                sce_frequency_hz = nb_sces / nb_seconds;
                avg_cells_sces = mean(sum(Race_gcamp,1));
    
                NCell = size(RasterRace_gcamp,1);
                pourcentageActif = zeros(nb_sces,1);
                for i = 1:nb_sces
                    nbActives = sum(RasterRace_gcamp(:,TRace_gcamp(i))==1);
                    pourcentageActif(i) = 100*nbActives/NCell;
                end
                avg_percent_cells_sces = mean(pourcentageActif);
    
                % --- Ajouter à la table ---
                new_row = {ages_num(sIdx), string(grp.animal_group), variability, cross_mean, activity_rate, ...
                           sce_frequency_hz, avg_cells_sces, avg_percent_cells_sces};
                results_table = [results_table; new_row];
            end
        end
    
        % --- Clustering et mapping des clusters en états interprétables ---
        if ~isempty(results_table)
            Xv = [results_table.variability, results_table.cross_mean, results_table.avg_percent_cells_sces];
            k = 4;
            [idx, cluster_centroids] = kmeans(Xv, k, 'Replicates',5);
    
            centroid_vals = cluster_centroids;
            med = median(Xv,1);
            state_names = strings(k,1);
            for i = 1:k
                var_high = centroid_vals(i,1) >= med(1);       % forte variabilité
                cross_high = centroid_vals(i,2) >= med(2);     % coordination élevée
                pct_high = centroid_vals(i,3) >= med(3);       % forte participation aux SCE
            
                % --- Nouvelles classes adaptées à la variabilité ---
                if var_high && cross_high && pct_high
                   state_names(i) = "Fluctuant & synchronisé & évènements de synchronicité";
                elseif var_high && cross_high && ~pct_high
                    state_names(i) = "Fluctuant & synchronisé (sans évènements de synchronicité)";
                elseif var_high && ~cross_high && pct_high
                    state_names(i) = "Fluctuant & désynchronisé & évènements de synchronicité";
                elseif var_high && ~cross_high && ~pct_high
                    state_names(i) = "Fluctuant & désynchronisé (sans évènements de synchronicité)";
                elseif ~var_high && cross_high && pct_high
                    state_names(i) = "Régulier & synchronisé & évènements de synchronicité";
                elseif ~var_high && cross_high && ~pct_high
                    state_names(i) = "Régulier & synchronisé (sans évènements de synchronicité)";
                elseif ~var_high && ~cross_high && pct_high
                    state_names(i) = "Régulier & désynchronisé & évènements de synchronicité";
                elseif ~var_high && ~cross_high && ~pct_high
                    state_names(i) = "Régulier & désynchronisé (sans évènements de synchronicité)";
                else
                    state_names(i) = "Mixte / intermédiaire";
                end
            end

            state_labels_all = state_names(idx);
            state_labels = categorical(state_labels_all);
    
            disp(['Résumé des états pour ', current_type]);
            disp(table((1:k)', state_names, 'VariableNames', {'Cluster','AssignedState'}));
    
            % --- Scatter 3D coloré par âge ---
            figure('Name',['3D scatter ', current_type],'NumberTitle','off'); hold on;
            x = results_table.variability;
            y = results_table.cross_mean;
            z = results_table.avg_percent_cells_sces;
            ages = results_table.session_age;
            sz_fixed = 50; % taille identique

            for i = 1:n_ages
                mask = ages == age_labels(i);
                if any(mask)
                    scatter3(x(mask), y(mask), z(mask), sz_fixed, ...
                        'MarkerFaceColor', age_colors(age_labels(i)), ...
                        'MarkerEdgeColor','k', 'DisplayName', sprintf('P%d', age_labels(i)), 'LineWidth',0.5);
                end
            end

            xlabel('Variabilité activité'); ylabel('Cross correlation'); zlabel('% cellules SCE');
            title(['Scatter 3D - ', current_type]);
            grid on; view(45,30);
            legend('Location','best'); set(gca,'FontSize',12);
            figs.(current_type).scatter3 = gcf;
    
            % --- Barplot proportionnel des états P7-P15 ---
            stacked_counts = zeros(n_ages, k);
            state_to_idx = containers.Map(state_names, 1:k);

            for s = 1:height(results_table)
                age = results_table.session_age(s);
                if age < 7 || age > 15
                    continue;
                end
                age_idx = age - 7 + 1;
                state_str = string(state_labels(s));
                if isKey(state_to_idx, state_str)
                    state_idx = state_to_idx(state_str);
                    stacked_counts(age_idx, state_idx) = stacked_counts(age_idx, state_idx) + 1;
                end
            end

            row_sums = sum(stacked_counts, 2);
            stacked_props = stacked_counts ./ row_sums;

            figure('Name', sprintf('Proportion d''états P7-P15 - %s', current_type), 'NumberTitle','off');
            bar(categorical(age_labels), stacked_props, 'stacked');
            ylabel('Proportion de sessions');
            xlabel('Âge (jours)');
            title(sprintf('Répartition proportionnelle des états P7-P15 - %s', current_type));
            legend(state_names, 'Location','bestoutside');
            grid on;
            ylim([0 1]);
            figs.(current_type).bar = gcf;
        end
    end
end
