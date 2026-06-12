function varargout = eval_counter(action)
% EVAL_COUNTER 评估计数器
%   eval_counter('reset') 重置计数器
%   count = eval_counter('get') 获取当前计数

    persistent COUNT
    if isempty(COUNT), COUNT = 0; end

    switch action
        case 'reset'
            COUNT = 0;
        case 'get'
            varargout{1} = COUNT;
        case 'inc'
            COUNT = COUNT + 1;
    end
end
