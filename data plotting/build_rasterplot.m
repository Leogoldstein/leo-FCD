function build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, sampling_rate_group)

    numFolders = numel(gcamp_output_folders);

    for m = 1:numFolders

        if isempty(gcamp_output_folders{m}) || ~iscell(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{1})
            fprintf('Group %d: gcamp_output_folders vide, skip.\n', m);
            continue;
        end

        fig = [];
        try
            sampling_rate = sampling_rate_group{m};
            root_folder_m = fileparts(gcamp_output_folders{m}{1});
            nPlanes = numel(gcamp_output_folders{m});

            %==========================================
            % movie branch
            %==========================================
            speed_active = [];
            if isfield(data, 'movie') && isstruct(data.movie) && ...
               isfield(data.movie, 'speed_active_group') && ...
               numel(data.movie.speed_active_group) >= m
                speed_active = data.movie.speed_active_group{m};
            end

            motion_energy_smooth = [];
            if isfield(data, 'movie') && isstruct(data.movie) && ...
               isfield(data.movie, 'motion_energy_smooth_group') && ...
               numel(data.movie.motion_energy_smooth_group) >= m
                motion_energy_smooth = data.movie.motion_energy_smooth_group{m};
            end

            has_motion_energy = ~isempty(motion_energy_smooth);

            %======================================================
            % 1) RASTERS PAR PLAN
            %======================================================
            for p = 1:nPlanes
                fig = [];
                try
                    [DFp, isort_p, MAct_p] = get_plane_data(data, m, p);

                    if isempty(DFp)
                        fprintf('Group %d plane %d: DF vide, skip raster plan.\n', m, p-1);
                        continue;
                    end

                    fig_save_path = fullfile(gcamp_output_folders{m}{p}, ...
                        sprintf('%s_%s_rastermap_gcamp_plane%d.png', ...
                        strrep(current_animal_group, ' ', '_'), ...
                        strrep(current_ages_group{m}, ' ', '_'), ...
                        p-1));

                    if exist(fig_save_path, 'file')
                        disp(['Figure already exists and was skipped: ' fig_save_path]);
                        continue;
                    end

                    [NCell, Nz] = size(DFp);
                    if NCell == 0 || Nz == 0
                        fprintf('Group %d plane %d: DF vide, skip.\n', m, p-1);
                        continue;
                    end

                    isort_p = sanitize_isort(isort_p, NCell);
                    MAct_p = resize_MAct(MAct_p, Nz);
                    prop_MAct_p = MAct_p / max(NCell, 1);

                    total_time = Nz / sampling_rate;
                    t_sec = (0:Nz-1) / sampling_rate;
                    activity_segs_sec = build_activity_segments(speed_active, total_time);

                    subplot_count = 2 + has_motion_energy;
                    fig = figure;
                    set(fig, 'Position', get(0, 'ScreenSize'));

                    % Raster
                    ax1 = subplot(subplot_count, 1, 1);
                    A = DFp(isort_p, :);
                    A_z = robust_zscore_rows(A);

                    imagesc(ax1, t_sec, 1:NCell, A_z);
                    axis(ax1, 'tight');
                    set(ax1, 'YDir', 'normal');
                    xlabel(ax1, 'Time (s)');
                    ylabel(ax1, 'Neurons');
                    colormap(ax1, parula);
                    apply_percentile_clim(ax1, A_z);
                    title(ax1, sprintf('Raster plot GCaMP plane %d (z-score)', p-1));
                    xlim(ax1, [0 total_time]);

                    % Prop active
                    ax2 = subplot(subplot_count, 1, 2);
                    plot(ax2, t_sec, prop_MAct_p, 'LineWidth', 2);
                    ylabel(ax2, 'Prop. Active Cells');
                    title(ax2, sprintf('Proportion of Active GCaMP Cells - plane %d', p-1));
                    grid(ax2, 'on');
                    xlim(ax2, [0 total_time]);
                    plot_activity_bands(ax2, activity_segs_sec);

                    axes_list = [ax1 ax2];

                    % Motion
                    if has_motion_energy
                        ax3 = subplot(subplot_count, 1, 3);
                        x_stretched = linspace(0, total_time, numel(motion_energy_smooth));
                        plot(ax3, x_stretched, motion_energy_smooth, 'LineWidth', 1);
                        xlabel(ax3, 'Time (s)');
                        ylabel(ax3, 'Motion energy');
                        title(ax3, 'Motion Energy');
                        grid(ax3, 'on');
                        xlim(ax3, [0 total_time]);
                        plot_activity_bands(ax3, activity_segs_sec);
                        axes_list = [axes_list ax3];
                    end

                    linkaxes(axes_list, 'x');
                    saveas(fig, fig_save_path);
                    disp(['Raster plot saved in: ' fig_save_path]);
                    close(fig);

                catch ME
                    fprintf('\nError for group %d plane %d: %s\n', m, p-1, ME.message);
                    if ~isempty(fig) && ishghandle(fig)
                        close(fig);
                    end
                end
            end

            %======================================================
            % 2) RASTER CONCATÉNÉ
            %======================================================
            fig = [];
            try
                [DF_concat, isort_concat, MAct_concat] = get_concat_data(data, m);

                if ~isempty(DF_concat)
                    fig_save_path = fullfile(root_folder_m, ...
                        sprintf('%s_%s_rastermap_gcamp_concat.png', ...
                        strrep(current_animal_group, ' ', '_'), ...
                        strrep(current_ages_group{m}, ' ', '_')));

                    if exist(fig_save_path, 'file')
                        disp(['Concatenated figure already exists and was skipped: ' fig_save_path]);
                    else
                        [NCell, Nz] = size(DF_concat);

                        isort_concat = sanitize_isort(isort_concat, NCell);
                        MAct_concat = resize_MAct(MAct_concat, Nz);
                        prop_MAct = MAct_concat / max(NCell,1);

                        total_time = Nz / sampling_rate;
                        t_sec = (0:Nz-1) / sampling_rate;
                        activity_segs_sec = build_activity_segments(speed_active, total_time);

                        subplot_count = 2 + has_motion_energy;
                        fig = figure;
                        set(fig, 'Position', get(0, 'ScreenSize'));

                        % Raster concat
                        ax1 = subplot(subplot_count, 1, 1);
                        A = DF_concat(isort_concat, :);
                        A_z = robust_zscore_rows(A);

                        imagesc(ax1, t_sec, 1:NCell, A_z);
                        axis(ax1, 'tight');
                        set(ax1, 'YDir', 'normal');
                        xlabel(ax1, 'Time (s)');
                        ylabel(ax1, 'Neurons');
                        colormap(ax1, parula);
                        apply_percentile_clim(ax1, A_z);
                        title(ax1, 'Raster plot GCaMP concaténé (z-score)');
                        xlim(ax1, [0 total_time]);

                        % Prop active concat
                        ax2 = subplot(subplot_count, 1, 2);
                        plot(ax2, t_sec, prop_MAct, 'LineWidth', 2);
                        ylabel(ax2, 'Prop. Active Cells');
                        title(ax2, 'Proportion of Active GCaMP Cells - concaténé');
                        grid(ax2, 'on');
                        xlim(ax2, [0 total_time]);
                        plot_activity_bands(ax2, activity_segs_sec);

                        axes_list = [ax1 ax2];

                        % Motion
                        if has_motion_energy
                            ax3 = subplot(subplot_count, 1, 3);
                            x_stretched = linspace(0, total_time, numel(motion_energy_smooth));
                            plot(ax3, x_stretched, motion_energy_smooth, 'LineWidth', 1);
                            xlabel(ax3, 'Time (s)');
                            ylabel(ax3, 'Motion energy');
                            title(ax3, 'Motion Energy');
                            grid(ax3, 'on');
                            xlim(ax3, [0 total_time]);
                            plot_activity_bands(ax3, activity_segs_sec);
                            axes_list = [axes_list ax3];
                        end

                        linkaxes(axes_list, 'x');
                        saveas(fig, fig_save_path);
                        disp(['Concatenated raster plot saved in: ' fig_save_path]);
                        close(fig);
                    end
                else
                    fprintf('Group %d: DF concaténé vide, skip raster concat.\n', m);
                end

            catch ME
                fprintf('\nError for concatenated raster group %d: %s\n', m, ME.message);
                if ~isempty(fig) && ishghandle(fig)
                    close(fig);
                end
            end

            %======================================================
            % 3) SUMMARY ROOT FOLDER : PLANS + CONCATÉNÉ + motion
            %======================================================
            fig = [];
            try
                fig_save_summary = fullfile(root_folder_m, ...
                    sprintf('%s_%s_rastermap_gcamp_summary.png', ...
                    strrep(current_animal_group, ' ', '_'), ...
                    strrep(current_ages_group{m}, ' ', '_')));

                if exist(fig_save_summary, 'file')
                    disp(['Summary figure already exists and was skipped: ' fig_save_summary]);
                else
                    valid_plane_idx = [];
                    for p = 1:nPlanes
                        [DFp, ~, ~] = get_plane_data(data, m, p);
                        if ~isempty(DFp)
                            valid_plane_idx(end+1) = p; %#ok<AGROW>
                        end
                    end

                    [DF_concat, isort_concat, MAct_concat] = get_concat_data(data, m);

                    has_concat = ~isempty(DF_concat);
                    has_summary_motion = has_motion_energy;

                    if isempty(valid_plane_idx) && ~has_concat
                        fprintf('Group %d: no valid planes for summary figure.\n', m);
                    else
                        nValidPlanes = numel(valid_plane_idx);
                        nRows_main = nValidPlanes + has_concat;
                        nRows = nRows_main + has_summary_motion;
                        nCols = 2;

                        fig = figure;
                        set(fig, 'Position', get(0, 'ScreenSize'));

                        row_counter = 0;

                        %------------------------------
                        % Lignes par plan
                        %------------------------------
                        for idx = 1:nValidPlanes
                            p = valid_plane_idx(idx);
                            [DFp, isort_p, MAct_p] = get_plane_data(data, m, p);

                            [NCell_p, Nz_p] = size(DFp);
                            if NCell_p == 0 || Nz_p == 0
                                continue;
                            end

                            row_counter = row_counter + 1;

                            isort_p = sanitize_isort(isort_p, NCell_p);
                            MAct_p = resize_MAct(MAct_p, Nz_p);
                            prop_MAct_p = MAct_p / max(NCell_p,1);

                            total_time_p = Nz_p / sampling_rate;
                            t_sec_p = (0:Nz_p-1) / sampling_rate;
                            activity_segs_sec_p = build_activity_segments(speed_active, total_time_p);

                            ax_r = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                            A = DFp(isort_p, :);
                            A_z = robust_zscore_rows(A);

                            imagesc(ax_r, t_sec_p, 1:NCell_p, A_z);
                            axis(ax_r, 'tight');
                            set(ax_r, 'YDir', 'normal');
                            colormap(ax_r, parula);
                            apply_percentile_clim(ax_r, A_z);
                            xlim(ax_r, [0 total_time_p]);
                            ylabel(ax_r, sprintf('Plane %d\nNeurons', p-1));
                            title(ax_r, sprintf('Raster plane %d', p-1));

                            ax_a = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                            plot(ax_a, t_sec_p, prop_MAct_p, 'LineWidth', 1.5);
                            grid(ax_a, 'on');
                            xlim(ax_a, [0 total_time_p]);
                            ylabel(ax_a, 'Prop. active');
                            title(ax_a, sprintf('Active cells plane %d', p-1));
                            plot_activity_bands(ax_a, activity_segs_sec_p);
                        end

                        %------------------------------
                        % Ligne concaténé
                        %------------------------------
                        if has_concat
                            row_counter = row_counter + 1;

                            [NCell_c, Nz_c] = size(DF_concat);
                            isort_concat = sanitize_isort(isort_concat, NCell_c);
                            MAct_concat = resize_MAct(MAct_concat, Nz_c);
                            prop_MAct_c = MAct_concat / max(NCell_c,1);

                            total_time_c = Nz_c / sampling_rate;
                            t_sec_c = (0:Nz_c-1) / sampling_rate;
                            activity_segs_sec_c = build_activity_segments(speed_active, total_time_c);

                            ax_r = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                            A = DF_concat(isort_concat, :);
                            A_z = robust_zscore_rows(A);

                            imagesc(ax_r, t_sec_c, 1:NCell_c, A_z);
                            axis(ax_r, 'tight');
                            set(ax_r, 'YDir', 'normal');
                            colormap(ax_r, parula);
                            apply_percentile_clim(ax_r, A_z);
                            xlim(ax_r, [0 total_time_c]);
                            ylabel(ax_r, 'Concat\nNeurons');
                            title(ax_r, 'Raster concaténé');

                            ax_a = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                            plot(ax_a, t_sec_c, prop_MAct_c, 'LineWidth', 1.5);
                            grid(ax_a, 'on');
                            xlim(ax_a, [0 total_time_c]);
                            ylabel(ax_a, 'Prop. active');
                            title(ax_a, 'Active cells concaténé');
                            plot_activity_bands(ax_a, activity_segs_sec_c);
                        end

                        %------------------------------
                        % Dernière ligne : motion energy sur 2 colonnes
                        %------------------------------
                        if has_summary_motion
                            row_counter = row_counter + 1;

                            if ~isempty(motion_energy_smooth)
                                if has_concat
                                    total_time_motion = Nz_c / sampling_rate;
                                elseif ~isempty(valid_plane_idx)
                                    p0 = valid_plane_idx(1);
                                    [DF0, ~, ~] = get_plane_data(data, m, p0);
                                    total_time_motion = size(DF0, 2) / sampling_rate;
                                else
                                    total_time_motion = numel(motion_energy_smooth);
                                end

                                t_motion = linspace(0, total_time_motion, numel(motion_energy_smooth));
                                activity_segs_sec_m = build_activity_segments(speed_active, total_time_motion);

                                % Colonne gauche
                                ax_m1 = subplot(nRows, nCols, (row_counter-1)*nCols + 1);
                                plot(ax_m1, t_motion, motion_energy_smooth, 'LineWidth', 1.5);
                                grid(ax_m1, 'on');
                                xlim(ax_m1, [0 total_time_motion]);
                                xlabel(ax_m1, 'Time (s)');
                                ylabel(ax_m1, 'Motion');
                                title(ax_m1, 'Motion energy');
                                plot_activity_bands(ax_m1, activity_segs_sec_m);

                                % Colonne droite
                                ax_m2 = subplot(nRows, nCols, (row_counter-1)*nCols + 2);
                                plot(ax_m2, t_motion, motion_energy_smooth, 'LineWidth', 1.5);
                                grid(ax_m2, 'on');
                                xlim(ax_m2, [0 total_time_motion]);
                                xlabel(ax_m2, 'Time (s)');
                                ylabel(ax_m2, 'Motion');
                                title(ax_m2, 'Motion energy');
                                plot_activity_bands(ax_m2, activity_segs_sec_m);
                            end
                        else
                            for c = 1:nCols
                                ax_last = subplot(nRows, nCols, (row_counter-1)*nCols + c);
                                xlabel(ax_last, 'Time (s)');
                            end
                        end

                        sgtitle(sprintf('%s - %s - Raster summary', ...
                            strrep(current_animal_group, '_', '\_'), ...
                            strrep(current_ages_group{m}, '_', '\_')));

                        saveas(fig, fig_save_summary);
                        disp(['Summary raster plot saved in: ' fig_save_summary]);
                        close(fig);
                    end
                end

            catch ME
                fprintf('\nError for summary raster group %d: %s\n', m, ME.message);
                if ~isempty(fig) && ishghandle(fig)
                    close(fig);
                end
            end

        catch ME
            fprintf('\nError for group %d: %s\n', m, ME.message);
            if ~isempty(fig) && ishghandle(fig)
                close(fig);
            end
        end
    end
end


%==========================================================
% HELPERS
%==========================================================

function [DFp, isort_p, MAct_p] = get_plane_data(data, m, p)

    DFp = [];
    isort_p = [];
    MAct_p = [];

    if isfield(data, 'gcamp_plane') && isstruct(data.gcamp_plane)
        if isfield(data.gcamp_plane, 'DF_gcamp_by_plane') && ...
           numel(data.gcamp_plane.DF_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.DF_gcamp_by_plane{m}) && ...
           numel(data.gcamp_plane.DF_gcamp_by_plane{m}) >= p
            DFp = data.gcamp_plane.DF_gcamp_by_plane{m}{p};
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

function [DF_concat, isort_concat, MAct_concat] = get_concat_data(data, m)

    DF_concat = [];
    isort_concat = [];
    MAct_concat = [];

    if isfield(data, 'gcamp_plane') && isstruct(data.gcamp_plane)
        if isfield(data.gcamp_plane, 'DF_gcamp_by_plane') && ...
           numel(data.gcamp_plane.DF_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.DF_gcamp_by_plane{m})
            DF_concat = concat_planes(data.gcamp_plane, m, 'DF_gcamp_by_plane');
        elseif isfield(data.gcamp_plane, 'DF_gcamp') && numel(data.gcamp_plane.DF_gcamp) >= m
            DF_concat = data.gcamp_plane.DF_gcamp{m};
        end

        if isfield(data.gcamp_plane, 'isort1_gcamp_by_plane') && ...
           numel(data.gcamp_plane.isort1_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.isort1_gcamp_by_plane{m})
            isort_concat = build_isort_from_planes(data.gcamp_plane, m, 'isort1_gcamp_by_plane', 'DF_gcamp_by_plane');
        elseif isfield(data.gcamp_plane, 'isort1_gcamp') && numel(data.gcamp_plane.isort1_gcamp) >= m
            isort_concat = data.gcamp_plane.isort1_gcamp{m};
        end

        if isfield(data.gcamp_plane, 'MAct_gcamp_by_plane') && ...
           numel(data.gcamp_plane.MAct_gcamp_by_plane) >= m && ...
           ~isempty(data.gcamp_plane.MAct_gcamp_by_plane{m})
            MAct_concat = merge_MAct_planes(data.gcamp_plane, m, 'MAct_gcamp_by_plane');
        elseif isfield(data.gcamp_plane, 'MAct_gcamp') && numel(data.gcamp_plane.MAct_gcamp) >= m
            MAct_concat = data.gcamp_plane.MAct_gcamp{m};
        end
    end
end

function Xcat = concat_planes(branch, m, fieldName)

    Xcat = [];

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
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

    nCols = cellfun(@(x) size(x,2), Xcell);
    Nz = min(nCols);

    for k = 1:numel(Xcell)
        Xcell{k} = Xcell{k}(:, 1:Nz);
    end

    Xcat = cat(1, Xcell{:});
end

function MAct_sum = merge_MAct_planes(branch, m, fieldName)

    MAct_sum = [];

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
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

function isort_global = build_isort_from_planes(branch, m, isort_field, DF_field)

    isort_global = [];

    if ~isfield(branch, isort_field) || ~isfield(branch, DF_field) || ...
       numel(branch.(isort_field)) < m || numel(branch.(DF_field)) < m || ...
       isempty(branch.(DF_field){m})
        return;
    end

    isort_cell = branch.(isort_field){m};
    DF_cell    = branch.(DF_field){m};

    if isempty(DF_cell)
        return;
    end

    offset = 0;

    for p = 1:numel(DF_cell)
        DFp = DF_cell{p};
        if isempty(DFp)
            continue;
        end

        n_p = size(DFp, 1);

        if p <= numel(isort_cell) && ~isempty(isort_cell{p})
            local_isort = isort_cell{p};
        else
            local_isort = (1:n_p)';
        end

        local_isort = sanitize_isort(local_isort, n_p);
        if numel(local_isort) ~= n_p
            local_isort = (1:n_p)';
        end

        isort_global = [isort_global; local_isort + offset]; %#ok<AGROW>
        offset = offset + n_p;
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

function Z = robust_zscore_rows(A)

    Z = nan(size(A));

    for i = 1:size(A,1)
        x = A(i,:);
        mu = median(x, 'omitnan');
        sig = 1.4826 * mad(x, 1);

        if isfinite(sig) && sig > eps
            Z(i,:) = (x - mu) / sig;
        else
            Z(i,:) = x - mu;
        end
    end
end

function apply_percentile_clim(ax, A)

    v = A(isfinite(A));
    if isempty(v)
        return;
    end

    lo = prctile(v, 2);
    hi = prctile(v, 98);

    if isfinite(lo) && isfinite(hi) && hi > lo
        clim(ax, [lo hi]);
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
    ends   = find(d == -1) - 1;

    segs_sec = [t(starts(:))', t(ends(:))'];
end

function plot_activity_bands(ax, segs_sec)

    if isempty(segs_sec)
        return;
    end

    yl = ylim(ax);
    hold(ax, 'on');

    for k = 1:size(segs_sec,1)
        x1 = segs_sec(k,1);
        x2 = segs_sec(k,2);
        patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], ...
              [1 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.25);
    end

    ylim(ax, yl);
    hold(ax, 'off');
end