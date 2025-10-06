function [sce_n_cells_threshold, sce_ratio_threshold, TRace, Race, sces_distances, RasterRace] = ...
    select_synchronies(directory, synchronous_frames, WinActive, DF, MAct, MinPeakDistancesce, Raster, animal, date)
% Detects synchronous calcium events (SCEs) based on cell activity synchrony.
%
% Inputs:
% - directory: output folder for results
% - synchronous_frames: temporal window (frames) for synchrony
% - WinActive: active window (used for random shift)
% - DF: ΔF/F traces (n_cells x time)
% - MAct: total number of active cells over time (1 x T)
% - MinPeakDistancesce: minimal distance between SCEs (frames)
% - Raster: binary activity matrix (n_cells x T)
% - animal, date: identifiers for output naming
%
% Outputs:
% - sce_n_cells_threshold : absolute threshold (#cells)
% - sce_ratio_threshold   : normalized threshold (fraction)
% - TRace                 : frame indices of detected SCE peaks
% - Race, RasterRace      : SCE-related activity matrices
% - sces_distances        : [peak_frame, event_duration]

    try
        [NCell, Nz] = size(DF);
        NShfl = 100;                    % number of shuffles
        percentile = 95;                % significance level

        % --- Step 1 : Shuffling-based null distribution ---
        Sumactsh = zeros(Nz - synchronous_frames, NShfl);

        for n = 1:NShfl
            Rastersh = zeros(NCell, Nz);
            for c = 1:NCell
                l = randi(Nz - length(WinActive));
                Rastersh(c,:) = circshift(Raster(c,:), l, 2);
            end

            MActsh = zeros(1, Nz - synchronous_frames);
            for i = 1:(Nz - synchronous_frames)
                MActsh(i) = sum(max(Rastersh(:, i:i + synchronous_frames), [], 2));
            end

            % Store as fraction of active cells
            Sumactsh(:, n) = MActsh / NCell;
        end

        % --- Step 2 : Determine significance threshold ---
        sce_ratio_threshold = prctile(Sumactsh, percentile, "all");
        sce_n_cells_threshold = sce_ratio_threshold * NCell;

        disp(['sce_ratio_threshold = ', num2str(sce_ratio_threshold, '%.3f')]);
        disp(['sce_n_cells_threshold = ', num2str(sce_n_cells_threshold)]);

        % --- Step 3 : Detect SCE peaks on normalized MAct ---
        MAct_ratio = MAct / NCell;
        [~, TRace] = findpeaks(MAct_ratio, ...
            'MinPeakHeight', sce_ratio_threshold, ...
            'MinPeakDistance', MinPeakDistancesce);

        NRace = length(TRace);
        disp(['Detected SCEs: ', num2str(NRace)]);

        % --- Step 4 : Compute event boundaries and durations ---
        sces_distances = zeros(NRace, 2);
        for i = 1:NRace
            left_idx = find(MAct_ratio(1:TRace(i)) < sce_ratio_threshold, 1, 'last');
            if isempty(left_idx), left_idx = 1; end

            right_idx = find(MAct_ratio(TRace(i):end) < sce_ratio_threshold, 1, 'first');
            if isempty(right_idx), right_idx = Nz - TRace(i); end
            right_idx = TRace(i) + right_idx - 1;

            duration = right_idx - left_idx;
            sces_distances(i, :) = [TRace(i), duration];
        end

        % --- Step 5 : Build Race / RasterRace matrices ---
        Race = zeros(NCell, NRace);
        RasterRace = zeros(NCell, Nz);

        for i = 1:NRace
            start_idx = max(TRace(i) - 1, 1);
            end_idx = min(TRace(i) + 2, Nz);
            Race(:, i) = max(Raster(:, start_idx:end_idx), [], 2);
            RasterRace(Race(:, i) == 1, TRace(i)) = 1;
        end

        % --- Step 6 : Visualization ---
        fig = figure('Units', 'normalized', 'OuterPosition', [0 0 1 1]);

        % Raster plot of detected events
        subplot(2, 1, 1);
        hold on;
        for i = 1:NCell
            spike_times = find(RasterRace(i, :));
            if ~isempty(spike_times)
                plot(spike_times, i * ones(1, numel(spike_times)), '.', 'Color', 'k');
            end
        end
        xlabel('Time (frames)');
        ylabel('Cell #');
        title('Raster of detected synchronous events (Race)');
        xlim([1 Nz]);
        hold off;

        % Global synchrony trace
        subplot(2, 1, 2);
        plot(MAct_ratio, 'k', 'LineWidth', 2); hold on;
        yline(sce_ratio_threshold, '--r', 'LineWidth', 1.5);
        plot(TRace, MAct_ratio(TRace), 'ro', 'MarkerFaceColor', 'r');
        xlabel('Frame');
        ylabel('Active cell ratio');
        title('Global synchrony and threshold');
        legend('MAct ratio', 'SCE threshold', 'Detected SCEs');
        xlim([1 Nz]); hold off;

        % Save figure and data
        fig_name = sprintf('SCEs_%s_%s', animal, date);
        saveas(fig, fullfile(directory, [fig_name '.png']));
        close(fig);

        save(fullfile(directory, 'results_SCEs.mat'), ...
            'Race', 'TRace', 'sces_distances', 'RasterRace', ...
            'sce_ratio_threshold', 'sce_n_cells_threshold');

    catch ME
        warning('Error in select_synchronies (%s): %s', directory, ME.message);
    end
end
