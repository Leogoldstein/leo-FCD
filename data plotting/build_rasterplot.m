function build_rasterplot(all_DF, all_isort1, all_MAct, gcamp_output_folders, current_animal_group, current_ages_group, all_sampling_rate, all_DF_all, all_isort1_all, all_DF_blue, all_MAct_blue, all_MAct_not_blue, motion_energy_group, avg_block)

    for m = 1:length(gcamp_output_folders)
        try
            % Extraction des données
            if (nargin < 8 || isempty(all_DF_all{m}))
                DF = all_DF{m};
                isort1 = all_isort1{m};
                sampling_rate = all_sampling_rate{m};
                MAct = all_MAct{m};
                MActblue = [];

                fig_save_path = fullfile(gcamp_output_folders{m}, sprintf('%s_%s_rastermap.png', ...
                    strrep(current_animal_group, ' ', '_'), strrep(current_ages_group{m}, ' ', '_')));

            elseif nargin > 7 && ~isempty(all_DF_all{m})
                DF = all_DF_all{m};
                DF_blue = all_DF_blue{m};
                isort1 = all_isort1_all{m};
                MAct = all_MAct_not_blue{m};
                MActblue = all_MAct_blue{m};
                sampling_rate = all_sampling_rate{m};

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

            shadow_width = 30;  % largeur de la bande en frames
            x_start = 1;        % position initiale
            
            hPatches = gobjects(subplot_count, 1);
            for idx = 1:subplot_count
                subplot(subplot_count, 1, idx);
                yl = ylim;
                hold on;
                hPatches(idx) = patch([x_start x_start+shadow_width x_start+shadow_width x_start], ...
                                      [yl(1) yl(1) yl(2) yl(2)], ...
                                      'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                                      'ButtonDownFcn', @startDragPatch);
                hold off;
            end
            
            % Stocker dans la figure
            fig = gcf;
            setappdata(fig, 'DraggablePatches', hPatches);
            setappdata(fig, 'SubplotCount', subplot_count);
            setappdata(fig, 'Nz', Nz);
            setappdata(fig, 'ShadowWidth', shadow_width);
            
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

function sliderCallback(src, w, fig_handle, subplot_count)
    val = src.Value;
    hPatches = getappdata(fig_handle, 'SliderPatches');
    for idx = 1:subplot_count
        subplot(subplot_count, 1, idx);
        yl = ylim;
        x_patch = [val val+w val+w val];
        set(hPatches(idx), 'XData', x_patch, 'YData', [yl(1) yl(1) yl(2) yl(2)]);
    end
    drawnow;
end

function startDragPatch(src, ~)
    fig = ancestor(src, 'figure');
    set(fig, 'WindowButtonMotionFcn', @(src, evt) draggingPatchFcn(src));
    set(fig, 'WindowButtonUpFcn', @(src, evt) stopDragPatchFcn(src));
end

function draggingPatchFcn(fig)
    cp = get(gca, 'CurrentPoint');
    x = cp(1,1);

    Nz = getappdata(fig, 'Nz');
    subplot_count = getappdata(fig, 'SubplotCount');
    shadow_width = getappdata(fig, 'ShadowWidth');
    hPatches = getappdata(fig, 'DraggablePatches');

    % Contraindre la bande dans les limites [1, Nz - shadow_width]
    x = max(1, min(Nz - shadow_width, x));

    for idx = 1:subplot_count
        subplot(subplot_count,1,idx);
        yl = ylim;
        set(hPatches(idx), 'XData', [x x+shadow_width x+shadow_width x], ...
                           'YData', [yl(1) yl(1) yl(2) yl(2)]);
    end
end

function stopDragPatchFcn(fig)
    set(fig, 'WindowButtonMotionFcn', '');
    set(fig, 'WindowButtonUpFcn', '');
end
