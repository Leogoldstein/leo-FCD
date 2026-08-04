function build_rasterplot_peaks(data, metadata, gcamp_output_folders, gcamp_root_folders, animal_path, current_line, current_animal_group, current_dates_group, current_ages_group, sampling_rate_group)

    numFolders = numel(gcamp_output_folders);

    line_file_name = strrep( ...
        char(string(current_line)), ...
        ' ', ...
        '_');
    
    if isempty(strtrim(line_file_name))
        line_prefix = '';
    else
        line_prefix = [line_file_name '_'];
    end

    animal_file_name = strrep(char(string(current_animal_group)), ' ', '_');

    for m = 1:numFolders

        if isempty(gcamp_output_folders{m}) || ~iscell(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{1})
            fprintf('Group %d: gcamp_output_folders vide, skip.\n', m);
            continue;
        end

        sampling_rate = sampling_rate_group{m};
        nPlanes = numel(gcamp_output_folders{m});

        if numel(current_dates_group) >= m && ~isempty(current_dates_group{m})
            current_date_text = char(string(current_dates_group{m}));
        else
            current_date_text = sprintf('Date_%d', m);
        end
        date_file_name = strrep(current_date_text, ' ', '_');

        if numel(current_ages_group) >= m && ~isempty(current_ages_group{m})
            current_age_text = char(string(current_ages_group{m}));
        else
            current_age_text = sprintf('Age_%d', m);
        end
        age_file_name = strrep(current_age_text, ' ', '_');

        %==========================================
        % motion branch
        %==========================================
        speed_active = [];
        if isfield(data, 'motion') && isstruct(data.motion) && ...
           isfield(data.motion, 'speed_active_group') && ...
           numel(data.motion.speed_active_group) >= m
            speed_active = data.motion.speed_active_group{m};
        end

        motion_energy = [];
        if isfield(data, 'motion') && isstruct(data.motion) && ...
           isfield(data.motion, 'motion_energy_group') && ...
           numel(data.motion.motion_energy_group) >= m
            motion_energy = data.motion.motion_energy_group{m};
        end

        has_motion_energy = ~isempty(motion_energy);

        line_width_trace = 1.5;

        %======================================================
        % 1) RASTERS DE PICS PAR PLAN
        %======================================================
        for p = 1:nPlanes

            fig = [];

            try
                fig_save_path = fullfile(gcamp_output_folders{m}{p}, ...
                    sprintf('%s%s_%s_%s_plane%d_peak_raster.png', ...
                    line_prefix, animal_file_name, date_file_name, age_file_name, p-1));

                if exist(fig_save_path, 'file') == 2
                    fprintf(['Plane peak raster already exists, ' ...
                        'all processing skipped:\n%s\n'], fig_save_path);
                    continue;
                end

                [Raster_p, isort_p, MAct_p] = get_plane_peak_data(data, m, p);

                if isempty(Raster_p)
                    fprintf('Group %d plane %d: Raster vide, skip raster peaks plan.\n', m, p-1);
                    continue;
                end

                [NCell, Nz] = size(Raster_p);

                if NCell == 0 || Nz == 0
                    fprintf('Group %d plane %d: Raster vide, skip.\n', m, p-1);
                    continue;
                end

                isort_p = sanitize_isort(isort_p, NCell);
                MAct_p = resize_MAct(MAct_p, Nz);
                prop_MAct_p = MAct_p / max(NCell, 1);

                total_time = Nz / sampling_rate;
                t_sec = (0:Nz-1) / sampling_rate;
                activity_segs_sec = build_activity_segments(speed_active, total_time);

                subplot_count = 2 + has_motion_energy;

                fig = figure('Color','w');
                set(fig, 'Position', [100 100 1200 650]);

                ax1 = subplot(subplot_count, 1, 1);
                A = Raster_p(isort_p, :);

                plot_peak_raster_visible(ax1, A, t_sec, 5);
                set(ax1,'TickLength',[0 0]);
                xlabel(ax1, 'Time (s)');
                ylabel(ax1, 'Neurons');
                title(ax1, sprintf('Peak raster GCaMP plane %d - sorted by DF isort1', p-1));
                xlim(ax1, [0 total_time]);

                ax2 = subplot(subplot_count, 1, 2);
                plot(ax2, t_sec, prop_MAct_p, 'LineWidth', line_width_trace);
                ylabel(ax2, 'Prop. Active Cells');
                title(ax2, sprintf('Proportion of Active GCaMP Cells - plane %d', p-1));
                grid(ax2, 'off');
                box(ax2, 'off');
                xlim(ax2, [0 total_time]);
                plot_activity_bands(ax2, activity_segs_sec);

                axes_list = [ax1 ax2];

                if has_motion_energy
                    ax3 = subplot(subplot_count, 1, 3);
                    x_stretched = linspace(0, total_time, numel(motion_energy));

                    plot(ax3, x_stretched, motion_energy, 'LineWidth', line_width_trace);
                    xlabel(ax3, 'Time (s)');
                    ylabel(ax3, 'Motion energy');
                    title(ax3, 'Motion Energy');
                    box(ax3, 'off');
                    grid(ax3, 'off');
                    xlim(ax3, [0 total_time]);
                    plot_activity_bands(ax3, activity_segs_sec);

                    axes_list = [axes_list ax3];
                end

                linkaxes(axes_list, 'x');

                saveas(fig, fig_save_path);
                disp(['Peak raster plot saved in: ' fig_save_path]);

                close(fig);
                fig = [];

            catch ME
                fprintf('\nError for group %d plane %d: %s\n', m, p-1, ME.message);

                if ~isempty(fig) && ishghandle(fig)
                    close(fig);
                end
            end
        end

        %======================================================
        % 2) RASTER DE PICS CONCATÉNÉ
        %======================================================
        if nPlanes > 1
            fig = [];
    
            try
                fig_save_path = fullfile(gcamp_root_folders{m}, ...
                    sprintf('%s_%s_%s_%s_peak_raster_concat.png', ...
                    line_prefix, animal_file_name, date_file_name, age_file_name));

                if exist(fig_save_path, 'file') == 2

                    fprintf(['Concatenated peak raster already exists, ' ...
                        'all processing skipped:\n%s\n'], fig_save_path);

                else

                    [Raster_concat, isort_concat, MAct_concat] = ...
                        get_concat_peak_data(data, m);

                    if isempty(Raster_concat)

                        fprintf('Group %d: Raster concaténé vide, skip peak raster concat.\n', m);

                    else

                        [NCell, Nz] = size(Raster_concat);
    
                        if NCell == 0 || Nz == 0
    
                            fprintf('Group %d: Raster concaténé vide, skip peak raster concat.\n', m);
    
                        else
    
                            isort_concat = sanitize_isort(isort_concat, NCell);
                            MAct_concat = resize_MAct(MAct_concat, Nz);
                            prop_MAct = MAct_concat / max(NCell, 1);
    
                            total_time = Nz / sampling_rate;
                            t_sec = (0:Nz-1) / sampling_rate;
                            activity_segs_sec = build_activity_segments(speed_active, total_time);
    
                            subplot_count = 2 + has_motion_energy;
    
                            fig = figure('Color','w');
                            set(fig, 'Position', [100 100 1200 650]);
    
                            ax1 = subplot(subplot_count, 1, 1);
                            A = Raster_concat(isort_concat, :);
    
                            plot_peak_raster_visible(ax1, A, t_sec);
                            set(ax1,'TickLength',[0 0]);
                            xlabel(ax1, 'Time (s)');
                            ylabel(ax1, 'Neurons');
                            %title(ax1, 'Peak raster GCaMP concaténé - sorted by DF isort1');
                            title(ax1, 'Sorted raster of GCaMP cells activity');
                            xlim(ax1, [0 total_time]);
    
                            ax2 = subplot(subplot_count, 1, 2);
                            plot(ax2, t_sec, prop_MAct, 'LineWidth', line_width_trace);
                            ylabel(ax2, 'Proportion (0-1)');
                            title(ax2, 'Proportion of Active GCaMP Cells');
                            grid(ax2, 'off');
                            box(ax2, 'off');
                            xlim(ax2, [0 total_time]);
                            %plot_activity_bands(ax2, activity_segs_sec);
    
                            axes_list = [ax1 ax2];
    
                            if has_motion_energy
                                ax3 = subplot(subplot_count, 1, 3);
                                x_stretched = linspace(0, total_time, numel(motion_energy));
    
                                plot(ax3, x_stretched, motion_energy, 'LineWidth', line_width_trace);
                                xlabel(ax3, 'Time (s)');
                                ylabel(ax3, 'Motion energy');
                                title(ax3, 'Motion Energy');
                                box(ax3, 'off');
                                grid(ax3, 'off');
                                xlim(ax3, [0 total_time]);
                                %plot_activity_bands(ax3, activity_segs_sec);
    
                                axes_list = [axes_list ax3];
                            end
    
                            linkaxes(axes_list, 'x');
    
                            saveas(fig, fig_save_path);
                            disp(['Concatenated peak raster plot saved in: ' fig_save_path]);
    
                            close(fig);
                            fig = [];
    
                        end
                    end
                end
    
                catch ME
                    fprintf('\nError for concatenated peak raster group %d: %s\n', m, ME.message);
        
                    if ~isempty(fig) && ishghandle(fig)
                        close(fig);
                    end
                end
        
                %======================================================
                % 3) SUMMARY ROOT FOLDER : PLANS + CONCATÉNÉ + MOTION
                %======================================================
                fig = [];
        
                try
                    fig_save_summary = fullfile(gcamp_root_folders{m}, ...
                        sprintf('%s_%s_%s_%s_peak_raster_summary.png', ...
                        line_prefix, animal_file_name, date_file_name, age_file_name));
        
                    if exist(fig_save_summary, 'file') == 2

                        fprintf(['Summary peak raster already exists, ' ...
                            'all processing skipped:\n%s\n'], fig_save_summary);

                    else
        
                        valid_plane_idx = [];
        
                        for p = 1:nPlanes
                            [Raster_p, ~, ~] = get_plane_peak_data(data, m, p);
        
                            if ~isempty(Raster_p)
                                valid_plane_idx(end+1) = p; %#ok<AGROW>
                            end
                        end
        
                        [Raster_concat, isort_concat, MAct_concat] = get_concat_peak_data(data, m);
        
                        has_concat = ~isempty(Raster_concat);
                        has_summary_motion = has_motion_energy;
        
                        if isempty(valid_plane_idx) && ~has_concat
        
                            fprintf('Group %d: no valid peak rasters for summary figure.\n', m);
        
                        else
        
                            nValidPlanes = numel(valid_plane_idx);
                            nRows_main = nValidPlanes + double(has_concat);
                            nRows = nRows_main + double(has_summary_motion);
                            nCols = 2;
        
                            fig = figure;
                            set(fig, 'Position', get(0, 'ScreenSize'));
        
                            row_counter = 0;
        
                            for idx = 1:nValidPlanes
        
                                p = valid_plane_idx(idx);
                                [Raster_p, isort_p, MAct_p] = get_plane_peak_data(data, m, p);
        
                                [NCell_p, Nz_p] = size(Raster_p);
        
                                if NCell_p == 0 || Nz_p == 0
                                    continue;
                                end
        
                                row_counter = row_counter + 1;
        
                                isort_p = sanitize_isort(isort_p, NCell_p);
                                MAct_p = resize_MAct(MAct_p, Nz_p);
                                prop_MAct_p = MAct_p / max(NCell_p, 1);
        
                                total_time_p = Nz_p / sampling_rate;
                                t_sec_p = (0:Nz_p-1) / sampling_rate;
                                activity_segs_sec_p = build_activity_segments(speed_active, total_time_p);
        
                                ax_r = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                                A = Raster_p(isort_p, :);
        
                                plot_peak_raster_visible(ax_r, A, t_sec_p);
                                set(ax_r,'TickLength',[0 0]);
                                xlabel(ax_r, 'Time (s)');
                                xlim(ax_r, [0 total_time_p]);
                                ylabel(ax_r, 'Concat\nNeurons');
                                title(ax_r, 'Peak raster concaténé');
                                ylabel(ax_r, sprintf('Plane %d\nNeurons', p-1));
                                title(ax_r, sprintf('Peak raster plane %d', p-1));
        
                                ax_a = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                                plot(ax_a, t_sec_p, prop_MAct_p, 'LineWidth', line_width_trace);
                                box(ax_a, 'off');
                                grid(ax_a, 'off');
                                xlim(ax_a, [0 total_time_p]);
                                ylabel(ax_a, 'Prop. active');
                                title(ax_a, sprintf('Active cells plane %d', p-1));
                                plot_activity_bands(ax_a, activity_segs_sec_p);
                            end
        
                            if has_concat
        
                                row_counter = row_counter + 1;
        
                                [NCell_c, Nz_c] = size(Raster_concat);
        
                                if NCell_c > 0 && Nz_c > 0
        
                                    isort_concat = sanitize_isort(isort_concat, NCell_c);
                                    MAct_concat = resize_MAct(MAct_concat, Nz_c);
                                    prop_MAct_c = MAct_concat / max(NCell_c, 1);
        
                                    total_time_c = Nz_c / sampling_rate;
                                    t_sec_c = (0:Nz_c-1) / sampling_rate;
                                    activity_segs_sec_c = build_activity_segments(speed_active, total_time_c);
        
                                    ax_r = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                                    A = Raster_concat(isort_concat, :);
                                    
                                    plot_peak_raster_visible(ax_r, A, t_sec_c);
                                    xlabel(ax_r, 'Time (s)');
                                    xlim(ax_r, [0 total_time_c]);
                                    ylabel(ax_r, 'Concat\nNeurons');
                                    title(ax_r, 'Peak raster concaténé');
        
                                    ax_a = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                                    plot(ax_a, t_sec_c, prop_MAct_c, 'LineWidth', line_width_trace);
                                    box(ax_a, 'off');
                                    grid(ax_a, 'off');
                                    xlim(ax_a, [0 total_time_c]);
                                    ylabel(ax_a, 'Prop. active');
                                    title(ax_a, 'Active cells concaténé');
                                    plot_activity_bands(ax_a, activity_segs_sec_c);
                                end
                            end
        
                            if has_summary_motion
        
                                row_counter = row_counter + 1;
        
                                if has_concat
                                    total_time_motion = size(Raster_concat, 2) / sampling_rate;
                                elseif ~isempty(valid_plane_idx)
                                    p0 = valid_plane_idx(1);
                                    [Raster0, ~, ~] = get_plane_peak_data(data, m, p0);
                                    total_time_motion = size(Raster0, 2) / sampling_rate;
                                else
                                    total_time_motion = numel(motion_energy);
                                end
        
                                t_motion = linspace(0, total_time_motion, numel(motion_energy));
                                activity_segs_sec_m = build_activity_segments(speed_active, total_time_motion);
        
                                ax_m1 = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                                plot(ax_m1, t_motion, motion_energy, 'LineWidth', line_width_trace);
                                box(ax_m1, 'off');
                                grid(ax_m1, 'off');
                                xlim(ax_m1, [0 total_time_motion]);
                                xlabel(ax_m1, 'Time (s)');
                                ylabel(ax_m1, 'Motion');
                                title(ax_m1, 'Motion energy');
                                plot_activity_bands(ax_m1, activity_segs_sec_m);
        
                                ax_m2 = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                                plot(ax_m2, t_motion, motion_energy, 'LineWidth', line_width_trace);
                                box(ax_m2, 'off');
                                grid(ax_m2, 'off');
                                xlim(ax_m2, [0 total_time_motion]);
                                xlabel(ax_m2, 'Time (s)');
                                ylabel(ax_m2, 'Motion');
                                title(ax_m2, 'Motion energy');
                                plot_activity_bands(ax_m2, activity_segs_sec_m);
        
                            else
        
                                for c = 1:nCols
                                    ax_last = subplot(nRows, nCols, (row_counter-1)*nCols + c);
                                    xlabel(ax_last, 'Time (s)');
                                end
                            end
        
                            sgtitle(sprintf('%s - %s - Peak raster summary', ...
                                strrep(current_animal_group, '_', '\_'), ...
                                strrep(current_ages_group{m}, '_', '\_')));
        
                            saveas(fig, fig_save_summary);
                            disp(['Summary peak raster plot saved in: ' fig_save_summary]);
        
                            close(fig);
                            fig = [];
                        end
                    end
    
            catch ME
                fprintf('\nError for summary peak raster group %d: %s\n', m, ME.message);
    
                if ~isempty(fig) && ishghandle(fig)
                    close(fig);
                end
            end
        end

        %======================================================
        % 4) SUMMARY ANIMAL : tous les rasters concaténés
        %======================================================
        if m == numFolders

            fig = [];

            try
                fig_save_animal = fullfile(animal_path, ...
                    sprintf('%s_%s_all_dates_all_ages_peak_concat_rasters.png', ...
                        line_prefix, animal_file_name));

                if exist(fig_save_animal, 'file') == 2

                    fprintf(['Animal peak concat raster summary already exists, ' ...
                        'all processing skipped:\n%s\n'], fig_save_animal);

                else

                    valid_dates = [];

                    for mm = 1:numFolders

                        [Raster_concat_mm, ~, ~] = get_concat_peak_data(data, mm);

                        if ~isempty(Raster_concat_mm)
                            valid_dates(end+1) = mm; %#ok<AGROW>
                        end
                    end

                    if isempty(valid_dates)

                        fprintf('Animal peak summary: aucun raster concaténé valide.\n');

                    elseif numel(valid_dates) < 2

                        fprintf('Animal peak summary: une seule date valide, figure non générée.\n');

                    else

                        ages_valid = nan(numel(valid_dates), 1);

                        for ii = 1:numel(valid_dates)
                            mm = valid_dates(ii);
                            ages_valid(ii) = extract_age_number(current_ages_group{mm});
                        end

                        [~, order_age] = sort(ages_valid, 'ascend', 'MissingPlacement', 'last');
                        valid_dates = valid_dates(order_age);

                        nRows = numel(valid_dates);
                    
                        fig = figure;
                        set(fig, 'Position', get(0, 'ScreenSize'));
                    
                        for idx = 1:nRows
                    
                            mm = valid_dates(idx);
                    
                            [Raster_concat, isort_concat, ~] = get_concat_peak_data(data, mm);
                    
                            if isempty(Raster_concat)
                                continue;
                            end
                    
                            sampling_rate_mm = sampling_rate_group{mm};
                    
                            [NCell, Nz] = size(Raster_concat);
                    
                            if NCell == 0 || Nz == 0
                                continue;
                            end
                    
                            isort_concat = sanitize_isort(isort_concat, NCell);
                    
                            total_time = Nz / sampling_rate_mm;
                            t_sec = (0:Nz-1) / sampling_rate_mm;
                    
                            ax = subplot(nRows, 1, idx);
                    
                            A = Raster_concat(isort_concat, :);
                    
                            plot_peak_raster_visible(ax, A, t_sec);
                            set(ax, 'TickLength', [0 0]);
                            xlim(ax, [0 total_time]);
                    
                            ylabel(ax, sprintf('%d neurons', NCell));
                    
                            title(ax, sprintf('%s - %s', ...
                                char(string(metadata.DateName{mm})), ...
                                char(string(current_ages_group{mm}))));
                    
                            if idx == nRows
                                xlabel(ax, 'Time (s)');
                            end
                        end
                    
                        sgtitle(sprintf('%s - all dates peak concat rasters', ...
                            strrep(current_animal_group, '_', '\_')));
                    
                        saveas(fig, fig_save_animal);
                    
                        fprintf('Animal peak concat raster summary saved in:\n%s\n', ...
                            fig_save_animal);
                    
                        close(fig);
                        fig = [];
                    
                    end
                end

            catch ME
                fprintf('\nError for animal peak concat raster summary: %s\n', ME.message);

                if ~isempty(fig) && ishghandle(fig)
                    close(fig);
                end
            end
        end
    end
end

%==========================================================
% HELPERS
%==========================================================

function [Raster_p, isort_p, MAct_p] = get_plane_peak_data(data, m, p)

    Raster_p = [];
    isort_p = [];
    MAct_p = [];

    if isfield(data, 'gcamp_plane') && isstruct(data.gcamp_plane)

        if isfield(data.gcamp_plane, 'Raster_gcamp_by_plane') && ...
           numel(data.gcamp_plane.Raster_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.Raster_gcamp_by_plane{m}) && ...
           numel(data.gcamp_plane.Raster_gcamp_by_plane{m}) >= p
            Raster_p = data.gcamp_plane.Raster_gcamp_by_plane{m}{p};
        end

        if isfield(data.gcamp_plane, 'isort1_gcamp_by_plane') && ...
           numel(data.gcamp_plane.isort1_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.isort1_gcamp_by_plane{m}) && ...
           numel(data.gcamp_plane.isort1_gcamp_by_plane{m}) >= p
            isort_p = data.gcamp_plane.isort1_gcamp_by_plane{m}{p};
        end

        if isfield(data.gcamp_plane, 'MAct_gcamp_by_plane') && ...
           numel(data.gcamp_plane.MAct_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.MAct_gcamp_by_plane{m}) && ...
           numel(data.gcamp_plane.MAct_gcamp_by_plane{m}) >= p
            MAct_p = data.gcamp_plane.MAct_gcamp_by_plane{m}{p};
        end
    end
end

function [Raster_concat, isort_concat, MAct_concat] = get_concat_peak_data(data, m)
    
    DF_concat = [];
    Raster_concat = [];
    isort_concat = [];
    MAct_concat = [];

    if isfield(data, 'gcamp_plane') && isstruct(data.gcamp_plane)

        if isfield(data.gcamp_plane, 'DF_gcamp_by_plane') && ...
           numel(data.gcamp_plane.DF_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.DF_gcamp_by_plane{m})

            DF_concat = concat_planes(data.gcamp_plane, m, 'DF_gcamp_by_plane');

        elseif isfield(data.gcamp_plane, 'DF_gcamp') && ...
               numel(data.gcamp_plane.DF_gcamp) >= m

            DF_concat = data.gcamp_plane.DF_gcamp{m};
        end

        if isfield(data.gcamp_plane, 'Raster_gcamp_by_plane') && ...
           numel(data.gcamp_plane.Raster_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.Raster_gcamp_by_plane{m})

            Raster_concat = concat_planes(data.gcamp_plane, m, 'Raster_gcamp_by_plane');

        elseif isfield(data.gcamp_plane, 'Raster_gcamp') && ...
               numel(data.gcamp_plane.Raster_gcamp) >= m

            Raster_concat = data.gcamp_plane.Raster_gcamp{m};
        end

        if ~isempty(DF_concat)
            ops_concat = [];
            
            if isfield(data.gcamp_plane,'ops_suite2p_by_plane') && ...
               numel(data.gcamp_plane.ops_suite2p_by_plane) >= m && ...
               ~isempty(data.gcamp_plane.ops_suite2p_by_plane{m})
            
                ops_concat = data.gcamp_plane.ops_suite2p_by_plane{m}{1};
            end
            if ~isempty(ops_concat)
        
                [isort_concat, ~, ~] = ...
                    compute_sort_outputs_from_df( ...
                        DF_concat, ...
                        ops_concat);        
            end
        end

        if isfield(data.gcamp_plane, 'MAct_gcamp_by_plane') && ...
           numel(data.gcamp_plane.MAct_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.MAct_gcamp_by_plane{m})

            MAct_concat = merge_MAct_planes(data.gcamp_plane, m, 'MAct_gcamp_by_plane');

        elseif isfield(data.gcamp_plane, 'MAct_gcamp') && ...
               numel(data.gcamp_plane.MAct_gcamp) >= m

            MAct_concat = data.gcamp_plane.MAct_gcamp{m};
        end
    end
end

function Xcat = concat_planes(branch, m, fieldName)

    Xcat = [];

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})
        return;
    end

    Xcell = branch.(fieldName){m};

    if isempty(Xcell)
        return;
    end

    valid = ~cellfun(@isempty, Xcell);
    Xcell = Xcell(valid);

    if isempty(Xcell)
        return;
    end

    nCols = cellfun(@(x) size(x, 2), Xcell);
    Nz = min(nCols);

    for k = 1:numel(Xcell)
        Xcell{k} = Xcell{k}(:, 1:Nz);
    end

    Xcat = cat(1, Xcell{:});
end

function MAct_sum = merge_MAct_planes(branch, m, fieldName)

    MAct_sum = [];

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})
        return;
    end

    MAct_cell = branch.(fieldName){m};

    if isempty(MAct_cell)
        return;
    end

    valid = ~cellfun(@isempty, MAct_cell);
    MAct_cell = MAct_cell(valid);

    if isempty(MAct_cell)
        return;
    end

    lengths = cellfun(@numel, MAct_cell);
    Nz = min(lengths);

    MAct_sum = zeros(1, Nz);

    for p = 1:numel(MAct_cell)
        M_p = MAct_cell{p};
        M_p = resize_MAct(M_p, Nz);
        MAct_sum = MAct_sum + M_p;
    end
end

function [isort1_out, isort2_out, Sm_out] = compute_sort_outputs_from_df(DF_in, ops_in)
    isort1_out = [];
    isort2_out = [];
    Sm_out     = [];

    if isempty(DF_in)
        return;
    end

    try
        [isort1_out, isort2_out, Sm_out] = ...
            raster_processing(double(DF_in), ops_in);
    catch ME
        warning('compute_sort_outputs_from_df:raster_processing', ...
            'raster_processing failed (%s).', ME.message);
        isort1_out = [];
        isort2_out = [];
        Sm_out     = [];
    end
end

function isort = sanitize_isort(isort, NCell)

    if isempty(isort)
        isort = (1:NCell)';
        return;
    end

    isort = isort(:);
    bad = isort < 1 | isort > NCell | isnan(isort);
    isort(bad) = [];

    if numel(isort) ~= NCell || numel(unique(isort)) ~= numel(isort)
        isort = (1:NCell)';
    end
end

function MAct_out = resize_MAct(MAct_in, Nz)

    if isempty(MAct_in)
        MAct_out = zeros(1, Nz);
        return;
    end

    MAct_in = MAct_in(:)';

    if numel(MAct_in) > Nz
        MAct_out = MAct_in(1:Nz);
    elseif numel(MAct_in) < Nz
        MAct_out = [MAct_in, zeros(1, Nz - numel(MAct_in))];
    else
        MAct_out = MAct_in;
    end
end

function segs_sec = build_activity_segments(speed_active, total_time)

    segs_sec = [];

    if isempty(speed_active)
        return;
    end

    L = numel(speed_active);
    t_speed = linspace(0, total_time, L);

    segs_sec = mask_to_segments_time(t_speed, speed_active > 0);
end

function segs_sec = mask_to_segments_time(t, mask)

    mask = mask(:)';
    t = t(:)';

    if isempty(mask)
        segs_sec = [];
        return;
    end

    d = diff([false, mask, false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;

    segs_sec = [t(starts(:))', t(ends(:))'];
end

function plot_activity_bands(ax, segs_sec)

    if isempty(segs_sec)
        return;
    end

    yl = ylim(ax);
    hold(ax, 'on');

    for k = 1:size(segs_sec, 1)

        x1 = segs_sec(k, 1);
        x2 = segs_sec(k, 2);

        patch(ax, ...
            [x1 x2 x2 x1], ...
            [yl(1) yl(1) yl(2) yl(2)], ...
            [1 0.8 0.8], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.25);
    end

    ylim(ax, yl);
    hold(ax, 'off');
end

function age_num = extract_age_number(age_value)

    age_num = NaN;

    if isempty(age_value)
        return;
    end

    txt = char(string(age_value));

    token = regexp(txt, '\d+(\.\d+)?', 'match', 'once');

    if ~isempty(token)
        age_num = str2double(token);
    end
end

function plot_peak_raster_visible(ax, A, t_sec, marker_size)

    if nargin < 4 || isempty(marker_size)
        nCells = size(A,1);

        % Taille progressive automatique
        marker_size = 2000 / nCells;

        % Bornes pour éviter points trop gros ou invisibles
        marker_size = max(0.4, min(8, marker_size));
    end

    [cell_idx, frame_idx] = find(A);

    scatter(ax, ...
        t_sec(frame_idx), ...
        cell_idx, ...
        marker_size, ...
        'k', ...
        'filled');

    set(ax,'YDir','reverse');
    set(ax,'TickLength',[0 0]);

    ylim(ax,[0.5 size(A,1)+0.5]);
    xlim(ax,[t_sec(1) t_sec(end)]);

    box(ax,'on');
    hold(ax,'off');
end