function [DFF0, Fzero, DFF0_raw, baseline_df] = F_processing(Tr1b, bad_frames, sampling_rate, window_size)

    [NCell, Nz] = size(Tr1b);

    half_win = floor(window_size / 2);
    step_size = floor(sampling_rate * 5);
    percentile_value = 10;

    frames_pour_1sec = max(1, floor(sampling_rate * 1));

    % Fenêtre pour retirer les oscillations lentes du dF/F
    % Doit être plus longue qu’un événement GCaMP complet.
    % 3 à 5 s est un bon départ.
    baseline_df_win_s = 4;
    baseline_df_win = max(3, round(baseline_df_win_s * sampling_rate));

    if mod(baseline_df_win, 2) == 0
        baseline_df_win = baseline_df_win + 1;
    end

    centers = 1:step_size:Nz;
    if centers(end) ~= Nz
        centers = [centers, Nz];
    end

    num_steps = length(centers);

    DFF0 = zeros(NCell, Nz);
    DFF0_raw = zeros(NCell, Nz);
    Fzero = zeros(NCell, Nz);
    baseline_df = zeros(NCell, Nz);

    for n = 1:NCell

        trace = Tr1b(n, :);

        trace_masked = trace;
        if exist('bad_frames', 'var') && ~isempty(bad_frames)
            trace_masked(bad_frames) = NaN;
        end

        anchor_X = zeros(1, num_steps);
        anchor_Y = zeros(1, num_steps);

        for i = 1:num_steps
            c = centers(i);

            idx_s = max(1, c - half_win);
            idx_e = min(Nz, c + half_win);

            segment = trace_masked(idx_s:idx_e);
            segment_lisse = movmean(segment, frames_pour_1sec, 'omitnan');

            anchor_X(i) = c;
            anchor_Y(i) = prctile(segment_lisse, percentile_value);
        end

        valid_anchors = ~isnan(anchor_Y);
        anchor_X = anchor_X(valid_anchors);
        anchor_Y = anchor_Y(valid_anchors);

        if length(anchor_X) > 1
            F0 = interp1(anchor_X, anchor_Y, 1:Nz, 'pchip', 'extrap');
        else
            F0 = repmat(nanmean(anchor_Y), 1, Nz);
        end

        df_raw = (trace - F0) ./ F0;

        % Masquer les bad frames avant correction lente
        df_for_baseline = df_raw;
        if exist('bad_frames', 'var') && ~isempty(bad_frames)
            df_for_baseline(bad_frames) = NaN;
        end

        % Baseline lente du dF/F : suit les oscillations lentes,
        % mais pas les transitoires GCaMP courts
        b = movmedian(df_for_baseline, baseline_df_win, 'omitnan');
        b = movmean(b, baseline_df_win, 'omitnan');

        % Remplissage si NaN locaux
        bad_b = ~isfinite(b);
        if any(bad_b) && any(~bad_b)
            b(bad_b) = interp1(find(~bad_b), b(~bad_b), find(bad_b), 'linear', 'extrap');
        elseif all(bad_b)
            b = zeros(size(df_raw));
        end

        df_corrected = df_raw - b;

        DFF0_raw(n, :) = df_raw;
        DFF0(n, :) = df_corrected;
        Fzero(n, :) = F0;
        baseline_df(n, :) = b;
    end
end