function [isort1, isort2, DFm] = mapTmap(DF, ops)
% run the activity map along the second dimension, then use this
% information to run it across the first dimension
% ops.nCall contains two numbers: number of clusters along dimension 1, and
% along dimension 2

if nargin<2
   ops = []; 
end

ops.nCall      = getOr(ops, 'nCall', [30 100]);


tic
ops.nC = ops.nCall(2);
[~, isort2, ~] = activityMap(DF', ops);
toc

DFm = my_conv2(DF(:, isort2), 3, 2); % smoothing constant here (3) is smoothing in resorted time
% sort DFm back in time

if max(isort2) > size(DF, 2)
    error('isort2 contains indices that exceed the number of columns in DF');
end

iresort(isort2) = 1:numel(isort2);
DFm = DFm(:, iresort);

ops.nC = ops.nCall(1);
[~, isort1, ~] = activityMap(DFm, ops);

DFm = my_conv2(DFm(isort1, :), 10, 1); % smoothing across neurons here (10)
DFm = zscore(DFm, 1, 2);

toc

end