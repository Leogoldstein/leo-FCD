function [traceF0, DF] = F_processing(F, bad_frames, window_size)

    [NCell, Nz] = size(F);
    percentile_value = 5;
    num_blocks = ceil(Nz / window_size);

    traceF0        = nan(NCell, Nz);
    DF             = nan(NCell, Nz);
 
    for n = 1:NCell
        trace = F(n, :);
        Nz = length(trace);

        % 1. Masquer les bad frames
        trace_masked = trace;
        if exist('bad_frames', 'var') && ~isempty(bad_frames)
            bad_idx = bad_frames(bad_frames >= 1 & bad_frames <= Nz);
            trace_masked(bad_idx) = NaN;
        end

        % --- baseline globale F0 ---
        anchor_X = zeros(1, num_blocks);
        anchor_Y = zeros(1, num_blocks);

        for i = 1:num_blocks
            idx_s = (i-1) * window_size + 1;
            idx_e = min(i * window_size, Nz);

            segment = trace_masked(idx_s:idx_e);
            val = prctile(segment, percentile_value);

            anchor_X(i) = (idx_s + idx_e) / 2;
            anchor_Y(i) = val;
        end

        valid_anchors = ~isnan(anchor_Y);
        anchor_X = anchor_X(valid_anchors);
        anchor_Y = anchor_Y(valid_anchors);

        if numel(anchor_X) > 1
            F0 = interp1(anchor_X, anchor_Y, 1:Nz, 'pchip', 'extrap');
        else
            F0 = repmat(nanmean(anchor_Y), 1, Nz);
        end

        traceF0(n, :) = F0;

        % --- dF/F ---
        DF(n, :) = (trace - F0) ./ F0;
    end
end