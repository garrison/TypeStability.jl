
export enable_inline_stability_checks, inline_stability_checks_enabled
export @stable_function, stability_warn


run_inline_stability_checks = false

"""
    enable_inline_stability_checks(::Bool)

Sets whether to run inline stability checks from [`@stable_function`](@ref).

If it is set to `false` (the default value), @stable_function does not perform
any type stability checks.

The value is checked when @stable_function is evaluated, so this should useually
be set at the begining of a package definition.

See [`inline_stability_checks_enabled`](@ref).
"""
function enable_inline_stability_checks(enabled::Bool)
    global run_inline_stability_checks
    run_inline_stability_checks = enabled
end

"""
    inline_stability_checks_enabled()::Bool

Returns whether inline stability checks are enabled.

See [`enable_inline_stability_checks`](@ref).
"""
function inline_stability_checks_enabled()::Bool
    run_inline_stability_checks
end


"""
    @stable_function arg_lists function_name
    @stable_function arg_lists function_definition(s)
    @stable_function arg_lists acceptable_instability function_name
    @stable_function arg_lists acceptable_instability function_definitions(s)

Checks the type stability of the function under the given argument lists.

If the second value is a function definition, the function is defined before
checking type stability.
"""
macro stable_function(arg_lists, unstable, func)
    if unstable isa Void || unstable == :nothing
        unstable = Dict{Symbol, Type}()
    end
    if run_inline_stability_checks
        (func_names, body) = parsebody(func)
        esc(quote
            $body
            $((:(TypeStability.stability_warn($name, TypeStability.check_function($name, $arg_lists, $unstable)))
               for name in func_names)...)
        end)
    else
        esc(func)
    end
end

macro stable_function(arg_lists, func)
    esc(:(@stable_function $arg_lists nothing $func))
end

"""
    parsebody(body)

Internal method to parse the last argument of @stable_function
"""
function parsebody(body::Expr; require_function=true)
    # TODO support `f(x) = x` function declarations
    if body.head == :function
        if body.args[1] isa Symbol
            func_names = [body.args[1]]
        elseif body.args[1].head == :call
            func_names = [body.args[1].args[1]]
        elseif body.args[1].head == :where && body.args[1].args[1].head == :call
            func_names = [body.args[1].args[1].args[1]]
        else
            error("Cannot find function name in $body")
        end
    elseif body.head == :macrocall
        expanded_body = macroexpand(body)
        if isa(expanded_body, Expr)
            (func_names, _) = parsebody(expanded_body; require_function=false)
        elseif isa(expanded_body, Symbol)
            func_names = [expanded_body]
        elseif require_function
            error("Cannot find a function name in macro expansion of $body")
        else
            func_names = Symbol[]
        end
    elseif body.head == :block
        func_names = Symbol[]
        for expr in body.args
            if isa(expr, Expr)
                (expr_func_names, _) = parsebody(expr; require_function=false)
                append!(func_names, expr_func_names)
            end
        end
        func_names = unique(func_names)
        if require_function && length(func_names) == 0
            error("Cannot find any function names in $body")
        end
    elseif require_function
        error("Don't know how to find function names in $body")
    else
        func_names = Symbol[]
    end
    (func_names, body)
end

function parsebody(func::Symbol)
    ([func], quote end)
end
