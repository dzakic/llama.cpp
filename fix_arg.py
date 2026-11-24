import sys

with open('common/arg.cpp', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    # The problem is that 'args.push_arg(common_arg' was added.
    # And the original was 'args.push_back(common_arg('.
    # So we have 'args.push_arg(common_arg' + '_arg(' -> 'args.push_arg(common_arg_arg('
    # Wait, if I replace 'args.push_arg(common_arg_arg(' with 'args.push_back(common_arg('
    # then it should work.
    
    # But let's be more general.
    # If the line has 'args.push_arg(common_arg_arg(', replace it.
    new_lines.append(line.replace('args.push_arg(common_arg_arg(', 'args.push_back(common_arg('))

with open('common/arg.cpp', 'w') as f:
    f.writelines(new_lines)
