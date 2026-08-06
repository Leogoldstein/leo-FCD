function show_masks_and_overlaps( ...
    meanImg, aligned_image, ...
    gcamp_mask, mask_cellpose, ...
    matched_gcamp_idx, matched_cellpose_idx, ...
    cellpose_unmatched_idx, ...
    matched_iou_values, ...
    gcamp_output_folder, fig_name)

% show_masks_and_overlaps
% Affichage avec masques remplis :
% - vert : GCaMP matchées
% - bleu : Cellpose matchées
% - rouge : Cellpose non matchées
%
% Numérotation des paires matchées sur les images
% + table récapitulative à droite :
%   # | GCaMP idx | Cellpose idx | IoU
%
% Layout :
%   [ image GCaMP ] [ image bleue ] [ table ]

    try
        if nargin < 9 || isempty(fig_name)
            fig_name = 'GCaMP_vs_Cellpose_masks';
        end

        matched_gcamp_idx      = matched_gcamp_idx(:);
        matched_cellpose_idx   = matched_cellpose_idx(:);
        cellpose_unmatched_idx = cellpose_unmatched_idx(:);

        if nargin < 8 || isempty(matched_iou_values)
            matched_iou_values = nan(min(numel(matched_gcamp_idx), numel(matched_cellpose_idx)), 1);
        else
            matched_iou_values = matched_iou_values(:);
        end

        nPairs = min([ ...
            numel(matched_gcamp_idx), ...
            numel(matched_cellpose_idx), ...
            numel(matched_iou_values)]);

        H = size(meanImg, 1);
        W = size(meanImg, 2);

        if size(aligned_image,1) ~= H || size(aligned_image,2) ~= W
            error('show_masks_and_overlaps:SizeMismatch', ...
                'meanImg = [%d %d], aligned_image = [%d %d].', ...
                size(meanImg,1), size(meanImg,2), size(aligned_image,1), size(aligned_image,2));
        end

        if ndims(gcamp_mask) ~= 3 || size(gcamp_mask,2) ~= H || size(gcamp_mask,3) ~= W
            error('show_masks_and_overlaps:GCaMPMaskSizeMismatch', ...
                'gcamp_mask = [%s], image = [%d %d].', ...
                num2str(size(gcamp_mask)), H, W);
        end

        if ndims(mask_cellpose) ~= 3 || size(mask_cellpose,2) ~= H || size(mask_cellpose,3) ~= W
            error('show_masks_and_overlaps:CellposeMaskSizeMismatch', ...
                'mask_cellpose = [%s], image = [%d %d].', ...
                num2str(size(mask_cellpose)), H, W);
        end

        hFig = figure('Position', [100, 100, 1500, 800]);

        % =====================================================
        % LEFT = image GCaMP
        % =====================================================
        ax1 = subplot(1,3,1);
        hold(ax1, 'on');
        imagesc(ax1, meanImg);
        colormap(ax1, gray);
        axis(ax1, 'image');
        set(ax1, 'YDir', 'reverse');

        % GCaMP matchées (vert)
        for k = 1:nPairs
            gi = matched_gcamp_idx(k);
            if gi < 1 || gi > size(gcamp_mask,1)
                continue;
            end

            Mi = squeeze(gcamp_mask(gi,:,:)) > 0;
            if ~any(Mi(:))
                continue;
            end

            rgb = cat(3, zeros(H,W), ones(H,W), zeros(H,W));
            h = imshow(rgb, 'Parent', ax1);
            set(h, 'AlphaData', 0.30 * double(Mi));
        end

        % Cellpose matchées (bleu)
        for k = 1:nPairs
            cj = matched_cellpose_idx(k);
            if cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;
            if ~any(Mj(:))
                continue;
            end

            rgb = cat(3, zeros(H,W), zeros(H,W), ones(H,W));
            h = imshow(rgb, 'Parent', ax1);
            set(h, 'AlphaData', 0.30 * double(Mj));
        end

        % Cellpose non matchées (rouge)
        for k = 1:numel(cellpose_unmatched_idx)
            cj = cellpose_unmatched_idx(k);
            if cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;
            if ~any(Mj(:))
                continue;
            end

            rgb = cat(3, ones(H,W), zeros(H,W), zeros(H,W));
            h = imshow(rgb, 'Parent', ax1);
            set(h, 'AlphaData', 0.30 * double(Mj));
        end

        % Numéros des paires
        for k = 1:nPairs
            gi = matched_gcamp_idx(k);
            cj = matched_cellpose_idx(k);

            if gi < 1 || gi > size(gcamp_mask,1) || cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mi = squeeze(gcamp_mask(gi,:,:)) > 0;
            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;

            [x_text, y_text, ok] = get_pair_label_position(Mi, Mj);

            if ok
                text(ax1, x_text, y_text, sprintf('%d', k), ...
                    'Color', [1 1 0], ...
                    'FontSize', 8, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Clipping', 'on');
            end
        end

        h1 = plot(ax1, nan, nan, '-', 'Color', [0 1 0], 'LineWidth', 4);
        h2 = plot(ax1, nan, nan, '-', 'Color', [0 0 1], 'LineWidth', 4);
        h3 = plot(ax1, nan, nan, '-', 'Color', [1 0 0], 'LineWidth', 4);

        legend(ax1, [h1 h2 h3], ...
            {'GCaMP matchées', 'Cellpose matchées', 'Cellpose non matchées'}, ...
            'Location', 'southoutside');

        title(ax1, 'GCaMP image (masques)');
        xlabel(ax1, 'X');
        ylabel(ax1, 'Y');
        hold(ax1, 'off');

        % =====================================================
        % MIDDLE = image bleue
        % =====================================================
        ax2 = subplot(1,3,2);
        hold(ax2, 'on');
        imagesc(ax2, aligned_image);
        colormap(ax2, gray);
        axis(ax2, 'image');
        set(ax2, 'YDir', 'reverse');

        % Cellpose matchées (bleu)
        for k = 1:nPairs
            cj = matched_cellpose_idx(k);
            if cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;
            if ~any(Mj(:))
                continue;
            end

            rgb = cat(3, zeros(H,W), zeros(H,W), ones(H,W));
            h = imshow(rgb, 'Parent', ax2);
            set(h, 'AlphaData', 0.30 * double(Mj));
        end

        % GCaMP matchées (vert)
        for k = 1:nPairs
            gi = matched_gcamp_idx(k);
            if gi < 1 || gi > size(gcamp_mask,1)
                continue;
            end

            Mi = squeeze(gcamp_mask(gi,:,:)) > 0;
            if ~any(Mi(:))
                continue;
            end

            rgb = cat(3, zeros(H,W), ones(H,W), zeros(H,W));
            h = imshow(rgb, 'Parent', ax2);
            set(h, 'AlphaData', 0.30 * double(Mi));
        end

        % Cellpose non matchées (rouge)
        for k = 1:numel(cellpose_unmatched_idx)
            cj = cellpose_unmatched_idx(k);
            if cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;
            if ~any(Mj(:))
                continue;
            end

            rgb = cat(3, ones(H,W), zeros(H,W), zeros(H,W));
            h = imshow(rgb, 'Parent', ax2);
            set(h, 'AlphaData', 0.30 * double(Mj));
        end

        % Numéros des paires
        for k = 1:nPairs
            gi = matched_gcamp_idx(k);
            cj = matched_cellpose_idx(k);

            if gi < 1 || gi > size(gcamp_mask,1) || cj < 1 || cj > size(mask_cellpose,1)
                continue;
            end

            Mi = squeeze(gcamp_mask(gi,:,:)) > 0;
            Mj = squeeze(mask_cellpose(cj,:,:)) > 0;

            [x_text, y_text, ok] = get_pair_label_position(Mi, Mj);

            if ok
                text(ax2, x_text, y_text, sprintf('%d', k), ...
                    'Color', [1 1 0], ...
                    'FontSize', 8, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Clipping', 'on');
            end
        end

        h1 = plot(ax2, nan, nan, '-', 'Color', [0 1 0], 'LineWidth', 4);
        h2 = plot(ax2, nan, nan, '-', 'Color', [0 0 1], 'LineWidth', 4);
        h3 = plot(ax2, nan, nan, '-', 'Color', [1 0 0], 'LineWidth', 4);

        legend(ax2, [h1 h2 h3], ...
            {'GCaMP matchées', 'Cellpose matchées', 'Cellpose non matchées'}, ...
            'Location', 'southoutside');

        title(ax2, 'Blue image (masques)');
        xlabel(ax2, 'X');
        ylabel(ax2, 'Y');
        hold(ax2, 'off');

        % =====================================================
        % RIGHT = table
        % =====================================================
        ax3 = subplot(1,3,3);
        axis(ax3, 'off');
        title(ax3, 'Matched pairs table');

        y0 = 0.98;
        dy = 0.055;

        text(ax3, 0.02, y0, '#', 'FontWeight', 'bold', 'Units', 'normalized');
        text(ax3, 0.12, y0, 'GCaMP', 'FontWeight', 'bold', 'Units', 'normalized');
        text(ax3, 0.42, y0, 'Cellpose', 'FontWeight', 'bold', 'Units', 'normalized');
        text(ax3, 0.78, y0, 'IoU', 'FontWeight', 'bold', 'Units', 'normalized');

        y = y0 - dy;
        max_rows = floor((y0 - 0.05) / dy);

        if nPairs == 0
            text(ax3, 0.02, y, 'No matched pairs', 'Units', 'normalized');
        else
            for k = 1:min(nPairs, max_rows)
                text(ax3, 0.02, y, sprintf('%d', k), 'Units', 'normalized');
                text(ax3, 0.12, y, sprintf('%d', matched_gcamp_idx(k)), 'Units', 'normalized');
                text(ax3, 0.42, y, sprintf('%d', matched_cellpose_idx(k)), 'Units', 'normalized');

                if isnan(matched_iou_values(k))
                    iou_str = 'NaN';
                else
                    iou_str = sprintf('%.3f', matched_iou_values(k));
                end
                text(ax3, 0.78, y, iou_str, 'Units', 'normalized');

                y = y - dy;
            end

            if nPairs > max_rows
                text(ax3, 0.02, y, sprintf('... + %d more pairs', nPairs - max_rows), ...
                    'Units', 'normalized', 'FontAngle', 'italic');
            end
        end

        drawnow;

        if ~isempty(gcamp_output_folder)
            saveas(hFig, fullfile(gcamp_output_folder, [fig_name '.png']));
            close(hFig);
        end

    catch ME
        fprintf('Erreur affichage masques: %s\n', ME.message);
    end
end


function [x_text, y_text, ok] = get_pair_label_position(Mi, Mj)

    ok = false;

    overlap_mask = Mi & Mj;

    if any(overlap_mask(:))
        [yy, xx] = find(overlap_mask);
        x0 = mean(xx);
        y0 = mean(yy);
    else
        [yyi, xxi] = find(Mi);
        [yyj, xxj] = find(Mj);

        if isempty(xxi) || isempty(xxj)
            x_text = NaN;
            y_text = NaN;
            return;
        end

        x0 = mean([mean(xxi), mean(xxj)]);
        y0 = mean([mean(yyi), mean(yyj)]);
    end

    H = size(Mi,1);
    W = size(Mi,2);
    union_mask = Mi | Mj;

    offsets = [ ...
         25 -25;
         30  30;
          0 -35;
         35   0;
        -35   0;
          0  35;
        -30 -30;
        -30  30];

    for i = 1:size(offsets,1)
        x_try = x0 + offsets(i,1);
        y_try = y0 + offsets(i,2);

        x_try = min(max(1, x_try), W);
        y_try = min(max(1, y_try), H);

        if ~union_mask(round(y_try), round(x_try))
            x_text = x_try;
            y_text = y_try;
            ok = true;
            return;
        end
    end

    x_text = min(max(1, x0 + 40), W);
    y_text = min(max(1, y0 - 40), H);
    ok = true;
end