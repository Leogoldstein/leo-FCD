function build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, motion_energy_group)

    for m = 1:length(gcamp_output_folders)
        try
            % Extraction des données
            if (nargin < 8 || isempty(data.DF_combined{m}))
                DF = data.DF_gcamp{m};
                isort1 = data.isort1_gcamp{m};
                sampling_rate = data.sampling_rate{m};
                MAct = data.MAct_gcamp{m};
                MActblue = [];

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            elseif nargin > 7 && ~isempty(data.DF_combined{m})
                DF = data.DF_combined{m};
                DF_blue = data.DF_blue{m};
                isort1 = data.isort1_combined{m};
                MAct = data.MAct_gcamp_not_blue{m};
                MActblue = data.MAct_blue{m};
                sampling_rate = data.sampling_rate{m};

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap_mtor.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));
            end

            % if exist(fig_save_path, 'file')
            %     disp(['Figure already exists and was skipped: ' fig_save_path]);
            %     continue;
            % end

            [NCell, Nz] = size(DF);
            % Adapter la longueur de MAct à Nz
            if length(MAct) > Nz
                MAct = MAct(1:Nz);
            elseif length(MAct) < Nz
                MAct = [MAct, zeros(1, Nz - length(MAct))];
            end
            prop_MAct = MAct / NCell;

            
            if ~isempty(MActblue)
                [NCell_blue, Nz_blue] = size(DF_blue);
            
                if length(MActblue) > Nz_blue
                    MActblue = MActblue(1:Nz_blue);
                elseif length(MActblue) < Nz_blue
                    MActblue = [MActblue, zeros(1, Nz_blue - length(MActblue))];
                end
                prop_MActblue = MActblue / NCell_blue;
            end

            has_motion_energy = nargin >= 14 && ~isempty(motion_energy_group) && ...
                                any(cellfun(@(x) ~isempty(x), motion_energy_group));
            subplot_count = 2 + ~isempty(MActblue) + has_motion_energy;
            subplot_idx = 2;

            % Création figure
            figure;
            screen_size = get(0, 'ScreenSize');
            set(gcf, 'Position', screen_size);

            % Subplot 1 : Raster plot
            % Suppression conversion en secondes
            t_idx = 1:Nz;
            
            % Subplot 1 : Raster plot
            subplot(subplot_count, 1, 1);
            imagesc(DF(isort1, :));
            [minValue, maxValue] = calculate_scaling(DF);
            clim([minValue, maxValue]);
            axis tight;
            
            ax1 = gca;
            ax1.XTick = round(linspace(1, Nz, 6));
            ax1.XTickLabel = arrayfun(@(x) sprintf('%d', x), ax1.XTick, 'UniformOutput', false);
            ylabel('Neurons');
            xlabel('Time (frame index)');
            title('Raster Plot');
            xlim([1 Nz]);

            
            % Subplot 2 : proportion active cells (all)
            subplot(subplot_count, 1, 2);
            plot(t_idx, prop_MAct, 'LineWidth', 2, 'Color', 'g');
            ylabel('Prop. Active Cells');
            title('Proportion of Active Cells (All)');
            grid on;
            xlim([1, Nz]);
            
            % Subplot cellules bleues
            subplot_idx = 3;
            if ~isempty(MActblue)
                subplot(subplot_count, 1, subplot_idx);
                plot(t_idx, prop_MActblue, 'LineWidth', 2, 'Color', 'b');
                xlim([1 Nz]);
                ylim([0 1]);
                xlabel('Time (frame index)');
                ylabel('Prop. Blue Active Cells');
                title('Proportion of Active Blue Cells');
                grid on;
                xlim([1, Nz]);
                subplot_idx = subplot_idx + 1;
            end
            
            % Subplot motion energy (inchangé mais attention à xlim ici aussi)
            if has_motion_energy
                subplot(subplot_count, 1, subplot_idx);
                hold on;
                
                energy = motion_energy_group{m};
                if isempty(energy)
                    continue;
                end
                
                % Créer un vecteur X qui va de 1 à Nz, avec length(energy) points
                x_stretched = linspace(1, Nz, length(energy));
                
                plot(x_stretched, energy, 'DisplayName', sprintf('Session %d', m));
                
                xlabel('Time (frame index)');
                ylabel('Normalized Energy');
                xlim([1 Nz]);
                title('Motion Energy (Downsampled)');
                legend show;
                grid on;
                hold off;

            end
            
            % Lier les axes X
            ax_all = findall(gcf, 'Type', 'axes');
            linkaxes(ax_all, 'x');

            % Optionnel : sauvegarde
            saveas(gcf, fig_save_path);
            disp(['Raster plot saved in: ' fig_save_path]);
            close(gcf)

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