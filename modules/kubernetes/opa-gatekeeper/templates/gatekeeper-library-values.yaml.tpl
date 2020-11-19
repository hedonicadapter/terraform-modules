constraints:
  %{~ for item in constraints ~}
  - kind: "${item.kind}"
    name: "${item.name}"
    %{~ if length(keys(item.match)) > 0 ~}
    match:
      ${indent(6, yamlencode(item.match))}
    %{~ endif ~}
    %{~ if length(keys(item.parameters)) > 0 ~}
    parameters:
      ${indent(6, yamlencode(item.parameters))}
    %{~ endif ~}
  %{~ endfor ~}
exclude:
  %{~ for item in exclude ~}
  - excludedNamespaces:
    %{~ for item in item.excluded_namespaces ~}
      - "${item}"
    %{~ endfor ~}
    processes:
    %{~ for item in item.processes ~}
      - "${item}"
    %{~ endfor ~}
  %{~ endfor ~}
