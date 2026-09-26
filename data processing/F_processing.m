function [DFF0, Fzero] = F_processing( ...
        Tr1b, ...
        bad_segs, ...
        sampling_rate, ...
        window_size)

    [NCell, Nz] = size(Tr1b);

    if Nz == 0
        DFF0 = zeros(NCell,0);
        Fzero = zeros(NCell,0);
        return;
    end

    half_win = floor(window_size / 2);
    step_size = max(1, floor(sampling_rate * 5));
    percentile_value = 10;

    frames_pour_1sec = ...
        max(1, floor(sampling_rate));

    % ==========================================================
    % Masque unique construit directement depuis bad_segs
    % ==========================================================

    bad_mask = false(1,Nz);

    if ~isempty(bad_segs)

        bad_segs = double(bad_segs);

        if isvector(bad_segs) && numel(bad_segs) == 2
            bad_segs = reshape(bad_segs,1,2);
        end

        if size(bad_segs,2) < 2
            error( ...
                'F_processing:InvalidBadSegments', ...
                'bad_segs doit etre une matrice Nx2 [debut fin].');
        end

        bad_segs = bad_segs(:,1:2);

        for k = 1:size(bad_segs,1)

            a = bad_segs(k,1);
            b = bad_segs(k,2);

            if ~isfinite(a) || ~isfinite(b)
                continue;
            end

            a = round(a);
            b = round(b);

            if a > b
                tmp = a;
                a = b;
                b = tmp;
            end

            a = max(1,a);
            b = min(Nz,b);

            if a <= b
                bad_mask(a:b) = true;
            end
        end
    end

    centers = 1:step_size:Nz;

    if centers(end) ~= Nz
        centers = [centers, Nz];
    end

    num_steps = numel(centers);

    DFF0 = zeros(NCell,Nz);
    Fzero = zeros(NCell,Nz);

    for n = 1:NCell

        trace = Tr1b(n,:);

        % Les segments artefactes sont exclus uniquement du calcul de F0.
        trace_masked = trace;
        trace_masked(bad_mask) = NaN;

        anchor_X = zeros(1,num_steps);
        anchor_Y = nan(1,num_steps);

        for i = 1:num_steps

            c = centers(i);

            idx_s = max(1,c-half_win);
            idx_e = min(Nz,c+half_win);

            segment = trace_masked(idx_s:idx_e);

            segment_lisse = ...
                movmean( ...
                    segment, ...
                    frames_pour_1sec, ...
                    'omitnan');

            anchor_X(i) = c;

            finite_segment = ...
                segment_lisse(isfinite(segment_lisse));

            if ~isempty(finite_segment)
                anchor_Y(i) = ...
                    prctile( ...
                        finite_segment, ...
                        percentile_value);
            end
        end

        valid_anchors = isfinite(anchor_Y);

        anchor_X = anchor_X(valid_anchors);
        anchor_Y = anchor_Y(valid_anchors);

        if numel(anchor_X) > 1

            F0 = ...
                interp1( ...
                    anchor_X, ...
                    anchor_Y, ...
                    1:Nz, ...
                    'pchip', ...
                    'extrap');

        elseif numel(anchor_X) == 1

            F0 = repmat(anchor_Y(1),1,Nz);

        else

            F0 = nan(1,Nz);
        end

        DFF0(n,:) = ...
            (trace - F0) ./ F0;

        Fzero(n,:) = ...
            F0;
    end
end
