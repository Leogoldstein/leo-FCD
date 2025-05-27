function build_rasterplot(all_DF, all_isort1, all_MAct, gcamp_output_folders, current_animal_group, current_ages_group, all_sampling_rate, all_DF_all, all_isort1_all, all_blue_indices, all_MAct_blue, motion_energy_group, avg_block)

    for m = 1:length(gcamp_output_folders)
        try
            % Extraction des données
            if (nargin < 8 || isempty(all_blue_indices{m}))
                DF = all_DF{m};
                isort1 = all_isort1{m};
                sampling_rate = all_sampling_rate{m};
                blue_indices = [];
                MActblue = [];
                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

                if exist(fig_save_path, 'file')
                    disp(['Figure already exists and was skipped: ' fig_save_path]);
                    continue;
                end

            elseif nargin > 7 && ~isempty(all_blue_indices{m})
                DF = all_DF_all{m};
                isort1  = all_isort1_all{m};
                blue_indices = all_blue_indices{m};
                MActblue = all_MAct_blue{m};
                sampling_rate = all_sampling_rate{m};

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap_mtor.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

                if exist(fig_save_path, 'file')
                    disp(['Figure already exists and was skipped: ' fig_save_path]);
                    continue;
                end
            end

            MAct = all_MAct{m};

            if ~isempty(isort1)
                isort1 = isort1(isort1 <= size(DF, 1));
            end      

            [NCell, Nz] = size(DF);

            % Ajustement longueur MAct
            if length(MAct) > Nz
                MAct = MAct(1:Nz);
            elseif length(MAct) < Nz
                warning('MAct length is less than number of timepoints. Padding with zeros.');
                MAct = [MAct, zeros(1, Nz - length(MAct))];
            end
            prop_MAct = MAct / NCell;

            % Ajustement MActblue si présent
            if ~isempty(MActblue)
                DF_blue = DF(blue_indices,:); 
                [NCell_blue, ~] = size(DF_blue);

                if length(MActblue) > Nz
                    MActblue = MActblue(1:Nz);
                elseif length(MActblue) < Nz
                    MActblue = [MActblue, zeros(1, Nz - length(MActblue))];
                end
                prop_MActblue = MActblue / NCell_blue;
            end

            % Nombre de subplots
            has_motion_energy = nargin >= 13 && ~isempty(motion_energy_group) && ...
                                 any(cellfun(@(x) ~isempty(x), motion_energy_group));
            subplot_count = 2 + ~isempty(MActblue) + has_motion_energy;
            subplot_idx = 2;

            % Création figure
            figure;
            screen_size = get(0, 'ScreenSize');
            set(gcf, 'Position', screen_size);

            % Subplot 1 : Raster plot
            subplot(subplot_count, 1, 1);
            imagesc(DF(isort1, :));
            [minValue, maxValue] = calculate_scaling(DF);
            clim([minValue, maxValue]);
            % colorbar supprimée
            axis tight;

            t_sec = (0:Nz-1) / sampling_rate;
            tick_positions = round(linspace(1, Nz, 6));
            ax1 = gca;
            ax1.XTick = tick_positions;
            ax1.XTickLabel = arrayfun(@(x) sprintf('%.1f', x / sampling_rate), tick_positions, 'UniformOutput', false);
            ylabel('Neurons');
            xlabel('Time (s)');
            title('Raster Plot');

            % Subplot 2 : proportion active cells (all)
            subplot(subplot_count, 1, subplot_idx);
            plot(t_sec, prop_MAct, 'LineWidth', 2, 'Color', 'g');
            ylabel('Prop. Active Cells');
            title('Proportion of Active Cells (All)');
            grid on;
            xlim([0, t_sec(end)]);
            subplot_idx = subplot_idx + 1;

            % Subplot cellules bleues
            if ~isempty(MActblue)
                subplot(subplot_count, 1, subplot_idx);
                plot(t_sec, prop_MActblue, 'LineWidth', 2, 'Color', 'b');
                ylim([0 1]);
                xlabel('Time (s)');
                ylabel('Prop. Blue Active Cells');
                title('Proportion of Active Blue Cells');
                grid on;
                xlim([0, t_sec(end)]);
                subplot_idx = subplot_idx + 1;
            end

            % Subplot motion energy
            if has_motion_energy
                subplot(subplot_count, 1, subplot_idx);
                hold on;

                energy = motion_energy_group{m};
                if isempty(energy)
                    continue;
                end

                dt = avg_block / sampling_rate;
                t_energy = (0:length(energy)-1) * dt;

                plot(t_energy, energy, 'DisplayName', sprintf('Session %d', m));

                xlabel('Time (s)');
                ylabel('Normalized Energy');
                title('Motion Energy (Downsampled)');
                legend show;
                grid on;
                hold off;
            end

            % --- Ajout d'un slider pour position temporelle ---
            % Récupérer la position du premier subplot (position = [left bottom width height])
            pos1 = subplot(subplot_count, 1, 1);
            pos1 = get(pos1, 'Position');
            
            % Position slider : même left et width, juste un peu en dessous du dernier subplot
            slider_height = 0.03; % hauteur slider
            slider_bottom = 0.05; % à ajuster si besoin (un peu au-dessus du bord bas de la figure)
            
            slider_pos = [pos1(1), slider_bottom, pos1(3), slider_height];
            
            % Création du slider
            hSlider = uicontrol('Style', 'slider', ...
                'Min', 0, 'Max', t_sec(end), 'Value', 0, ...
                'Units', 'normalized', ...
                'Position', slider_pos, ...
                'Callback', @(src,evt) sliderCallback(src, gcf, t_sec, subplot_count));

            
            % Création d’une zone d’ombre initiale sur tous les subplots
            % Stockage des handles des patches pour mise à jour
            hPatches = gobjects(subplot_count, 1);
            
            for idx = 1:subplot_count
                subplot(subplot_count,1,idx);
                yl = ylim;
                hold on;
                % Crée une zone verticale semi-transparente à x=0 (slider à 0)
                hPatches(idx) = patch([0 0.2 0.2 0], [yl(1) yl(1) yl(2) yl(2)], 'k', ...
                    'FaceAlpha', 0.1, 'EdgeColor', 'none');
                % S’assurer que le patch est au-dessus de tous les autres éléments graphiques
                uistack(hPatches(idx), 'top');
                hold off;
            end
            
            % Stockage des handles dans la figure pour accès dans callback
            setappdata(gcf, 'SliderPatches', hPatches);

            % Save & close (décommenter si voulu)
            % saveas(gcf, fig_save_path);
            % disp(['Raster plot saved in: ' fig_save_path]);
            % close(gcf);

        catch ME
            fprintf('\nError: %s\n', ME.message);
        end
    end
end

function [min_val, max_val] = calculate_scaling(data)
    flattened_data = data(:);
    min_val = prctile(flattened_data, 5);
    max_val = prctile(flattened_data, 99.9);
    if min_val >= max_val
        warning('Invalid color scale limits, using raw min/max.');
        min_val = min(flattened_data);
        max_val = max(flattened_data);
    end
end


function sliderCallback(src, fig_handle, t_sec, subplot_count)
    val = src.Value;
    % Largeur de l’ombre en secondes (modifiable)
    shadow_width = (t_sec(end) - t_sec(1)) * 0.01; 

    hPatches = getappdata(fig_handle, 'SliderPatches');
    for idx = 1:subplot_count
        subplot(subplot_count, 1, idx);
        yl = ylim;
        % Met à jour la position X de la zone d’ombre
        x_patch = [val val+shadow_width val+shadow_width val];
        set(hPatches(idx), 'XData', x_patch, 'YData', [yl(1) yl(1) yl(2) yl(2)]);
    end
end
