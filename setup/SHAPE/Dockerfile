FROM python

COPY setup/SHAPE/download_driver.sh /srv/external/setup/SHAPE/download_driver.sh

RUN sh /srv/external/setup/SHAPE/download_driver.sh

RUN pip install sqlalchemy pyodbc pandas

WORKDIR /srv/external

CMD ["python", "/srv/external/setup/SHAPE/pull_shape_db.py"]
# CMD ["/bin/bash"]