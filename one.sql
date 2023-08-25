if result:
    header_list = [str(i) for i in result[0]._asdict().keys()]
else:
    # Handle empty result case, e.g., set a default header_list
    header_list = []
