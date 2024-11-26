FROM python

COPY setup/SHAPE/download_driver.sh /srv/internal/setup/SHAPE/download_driver.sh

RUN sh /srv/internal/setup/SHAPE/download_driver.sh

RUN pip install sqlalchemy pyodbc pandas

WORKDIR /srv/internal

CMD ["python", "/srv/internal/setup/SHAPE/pull_shape_db.py"]
# CMD ["/bin/bash"]