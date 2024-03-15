
logger = logging.getLogger()

logger.setLevel(logging.DEBUG)

formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

file_handler = logging.FileHandler('lambdalogging.log')

file_handler.setFormatter(formatter)

logger.addHandler(file_handler)

console_handler = logging.StreamHandler()

console_handler.setFormatter(formatter)

logger.addHandler(console_handler)
