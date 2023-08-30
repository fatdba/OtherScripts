{
  "errorMessage": "name 'summary_list' is not defined",
  "errorType": "NameError",
  "requestId": "",
  "stackTrace": [
    "  File \"/var/lang/lib/python3.9/importlib/__init__.py\", line 127, in import_module\n    return _bootstrap._gcd_import(name[level:], package, level)\n",
    "  File \"<frozen importlib._bootstrap>\", line 1030, in _gcd_import\n",
    "  File \"<frozen importlib._bootstrap>\", line 1007, in _find_and_load\n",
    "  File \"<frozen importlib._bootstrap>\", line 986, in _find_and_load_unlocked\n",
    "  File \"<frozen importlib._bootstrap>\", line 680, in _load_unlocked\n",
    "  File \"<frozen importlib._bootstrap_external>\", line 850, in exec_module\n",
    "  File \"<frozen importlib._bootstrap>\", line 228, in _call_with_frames_removed\n",
    "  File \"/var/task/lambda_function.py\", line 936, in <module>\n    update_table(summary_list, summary_table_parameter_list, summary_table_name)\n"
  ]
}
